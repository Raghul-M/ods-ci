from kfp import compiler, dsl, kubernetes
from kfp.dsl import PipelineTask

# Runtime: Pytorch with ROCm and Python 3.11 (UBI 9)
# The images for each release can be found in
# https://github.com/red-hat-data-services/rhoai-disconnected-install-helper/blob/main/rhoai-2.21.md
common_base_image = "quay.io/modh/odh-pipeline-runtime-pytorch-rocm-py311-ubi9@sha256:d9fb9efa196afd97d8ff9c0bf4c5bd09a9f01bd03d1166bebf974c8bf18958c4"


def add_gpu_toleration(task: PipelineTask, accelerator_type: str, accelerator_limit: int):
    print(f"Adding GPU tolerations: {accelerator_type}({accelerator_limit})")
    task.set_accelerator_type(accelerator=accelerator_type)
    task.set_accelerator_limit(accelerator_limit)
    kubernetes.add_toleration(task, key=accelerator_type, operator="Exists", effect="NoSchedule")


@dsl.component(base_image=common_base_image)
def verify_gpu_availability(gpu_toleration: bool):
    import torch  # noqa: PLC0415

    cuda_available = torch.cuda.is_available()
    device_count = torch.cuda.device_count()
    print("------------------------------")
    print("GPU availability")
    print("------------------------------")
    print(f"cuda available: {cuda_available}")
    print(f"device count: {device_count}")
    if gpu_toleration:
        assert torch.cuda.is_available()
        assert torch.cuda.device_count() > 0
        t = torch.tensor([5, 5, 5], dtype=torch.int64, device="cuda")
    else:
        assert not torch.cuda.is_available()
        assert torch.cuda.device_count() == 0
        t = torch.tensor([5, 5, 5], dtype=torch.int64)
    print(f"tensor: {t}")
    print("GPU availability test: PASS")


@dsl.pipeline(
    name="pytorch-amd-gpu-availability",
    description="Verifies pipeline tasks run on GPU nodes only when tolerations are added",
)
def pytorch_amd_gpu_availability():
    verify_gpu_availability(gpu_toleration=False).set_caching_options(False)

    task_with_toleration = verify_gpu_availability(gpu_toleration=True).set_caching_options(False)
    add_gpu_toleration(task_with_toleration, "amd.com/gpu", 1)


if __name__ == "__main__":
    compiler.Compiler().compile(pytorch_amd_gpu_availability, package_path=__file__.replace(".py", "_compiled.yaml"))
