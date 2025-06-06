*** Settings ***
Documentation    Testing custom image imports (Adding ImageStream to ${APPLICATIONS_NAMESPACE})
Resource         ../../../Resources/ODS.robot
Resource         ../../../Resources/Common.robot
Resource         ../../../Resources/Page/ODH/JupyterHub/JupyterHubSpawner.robot
Resource         ../../../Resources/Page/ODH/JupyterHub/JupyterLabLauncher.robot
Resource         ../../../Resources/Page/ODH/JupyterHub/GPU.resource
Resource         ../../../Resources/Page/ODH/ODHDashboard/ODHDataScienceProject/Projects.resource
Resource         ../../../Resources/RHOSi.resource
Library          JupyterLibrary
Library          OpenShiftLibrary
Suite Setup      Custom Notebook Settings Suite Setup
Suite Teardown   End Web Test
Test Tags        JupyterHub



*** Variables ***
${YAML} =         tests/Resources/Files/custom_image.yaml
${IMG_NAME} =            custom-test-image
${IMG_URL} =             quay.io/opendatahub/workbench-images:jupyter-minimal-ubi9-python-3.11-2024b-20241004
${IMG_DESCRIPTION} =     Testing Only This image is only for illustration purposes, and comes with no support. Do not use.
&{IMG_SOFTWARE} =        Software1=x.y.z
&{IMG_PACKAGES} =        elyra=2.2.4    foo-pkg=a.b.c
# Place holder for the imagestream name of BYON notebook created for this test run
${IMAGESTREAM_NAME}=


*** Test Cases ***
Verify Admin User Can Access Custom Notebook Settings
    [Documentation]    Verifies an admin user can reach the custom notebook
    ...    settings page.
    [Tags]    Tier1
    ...       ODS-1366
    Pass Execution    Passing tests, as suite setup ensures page can be reached

Verify Custom Image Can Be Added
    [Documentation]    Imports the custom image via UI
    ...                Then loads the spawner and tries using the custom img
    [Tags]    Tier1    ExcludeOnDisconnected
    ...       ODS-1208    ODS-1365
    ${CLEANUP}=  Set Variable  False
    Create Custom Image
    Sleep    5s    #wait a bit from IS to be created
    Get ImageStream Metadata And Check Name
    Verify Custom Image Is Listed  ${IMG_NAME}
    Verify Custom Image Description  ${IMG_NAME}  ${IMG_DESCRIPTION}
    Verify Custom Image Provider  ${IMG_NAME}  ${TEST_USER.USERNAME}
    Launch JupyterHub Spawner From Dashboard

    # These keywords need to be reworked to function here
    #${spawner_description}=  Fetch Image Tooltip Description  ${IMAGESTREAM_NAME}
    #${spawner_packages}=  Fetch Image Tooltip Info  ${IMAGESTREAM_NAME}
    #${spawner_software}=  Fetch Image Description Info  ${IMAGESTREAM_NAME}
    #Should Match  ${spawner_description}  ${IMG_DESCRIPTION}
    #Should Match  ${spawner_software}  ${IMG_SOFTWARE}
    #Should Match  ${spawner_packages}  ${IMG_PACKAGES}

    Spawn Notebook With Arguments  image=${IMAGESTREAM_NAME}  size=Small
    ${CLEANUP}=  Set Variable  True
    [Teardown]  Custom Image Teardown  cleanup=${CLEANUP}

Test Duplicate Image
    [Documentation]  Test adding two images with the same name (should fail)
    ...       There was a bug related https://issues.redhat.com/browse/RHOAIENG-1192
    [Tags]    Tier1    ExcludeOnDisconnected
    ...       ODS-1368
    Sleep  1
    Create Custom Image
    Sleep  1
    Import New Custom Image    ${IMG_URL}    ${IMG_NAME}    ${IMG_DESCRIPTION}
    ...    software=${IMG_SOFTWARE}
    ...    packages=${IMG_PACKAGES}
    # Assure that the expected error message is shown in the modal window
    ${image_name_id}=  Replace String  ${IMG_NAME}  ${SPACE}  -
    Wait Until Page Contains    Unable to add notebook image: imagestreams.image.openshift.io "${image_name_id}" already exists
    # Since the image cannot be created, we need to cancel the modal window now
    Click Button    ${GENERIC_CANCEL_BTN_XP}
    [Teardown]  Duplicate Image Teardown

Test Bad Image URL
    [Documentation]  Test adding an image with a bad repo URL (should fail)
    [Tags]    Tier1
    ...       ODS-1367
    ${OG_URL}=  Set Variable  ${IMG_URL}
    ${IMG_URL}=  Set Variable  quay.io/RandomName/RandomImage:v1.2.3
    Set Global Variable  ${IMG_URL}  ${IMG_URL}
    Create Custom Image
    Wait Until Page Contains    Invalid repository URL: ${IMG_URL}
    # Since the image cannot be created, we need to cancel the modal window now
    Click Button    ${GENERIC_CANCEL_BTN_XP}
    [Teardown]  Bad Image URL Teardown  orig_url=${OG_URL}

Test Image From Local registry
    [Documentation]  Try creating a custom image using a local registry URL (i.e. OOTB image)
    [Tags]    Tier1
    ...       ODS-2470
    ...       ExcludeOnDisconnected    # Since we don't have internal image registry enabled there usually
    ...       InternalImageRegistry    # Requires internal image registry enabled
    ...       ProductBug               # https://issues.redhat.com/browse/RHOAIENG-1193
    ${CLEANUP}=  Set Variable  False
    Open Notebook Images Page
    ${local_url} =    Get Standard Data Science Local Registry URL
    ${IMG_URL}=    Set Variable    ${local_url}
    Set Suite Variable    ${IMG_URL}    ${IMG_URL}
    Create Custom Image
    Get ImageStream Metadata And Check Name
    Verify Custom Image Is Listed    ${IMG_NAME}
    Verify Custom Image Provider  ${IMG_NAME}  ${TEST_USER.USERNAME}
    Launch JupyterHub Spawner From Dashboard
    Spawn Notebook With Arguments  image=${IMAGESTREAM_NAME}  size=Small
    ${CLEANUP}=  Set Variable  True
    [Teardown]  Custom Image Teardown  cleanup=${CLEANUP}


*** Keywords ***

Custom Notebook Settings Suite Setup
    [Documentation]    Navigates to the Custom Notebook Settings page
    ...    in the RHODS dashboard.
    RHOSi Setup
    Set Library Search Order  SeleniumLibrary
    Launch Dashboard    ocp_user_name=${TEST_USER.USERNAME}    ocp_user_pw=${TEST_USER.PASSWORD}
    ...    ocp_user_auth_type=${TEST_USER.AUTH_TYPE}    dashboard_url=${ODH_DASHBOARD_URL}
    ...    browser=${BROWSER.NAME}    browser_options=${BROWSER.OPTIONS}
    Sleep  2
    Open Notebook Images Page

Custom Image Teardown
    [Documentation]    Closes the JL server and deletes the ImageStream
    [Arguments]    ${cleanup}=True
    IF  ${cleanup}==True
        Server Cleanup
    END
    Go To  ${ODH_DASHBOARD_URL}
    Open Notebook Images Page
    Delete Custom Image  ${IMG_NAME}
    Reset Image Name

Duplicate Image Teardown
    [Documentation]    Closes the Import image dialog (if present), deletes custom images
    ...    and resets the global variables
    ${is_modal}=  Is Generic Modal Displayed
    IF  ${is_modal} == ${TRUE}
      Click Button  ${GENERIC_CANCEL_BTN_XP}
    END
    Delete Custom Image  ${IMG_NAME}
    # If both imgs can be created they also have to be deleted twice
    Sleep  2
    ${exists} =  Run Keyword And Return Status  Page Should Contain Element  xpath://td[@data-label="Name"]/div/div/div[.="${IMG_NAME} "]  # robocop: disable
    IF  ${exists}==True
      Delete Custom Image  ${IMG_NAME}
    END
    Reset Image Name

Bad Image URL Teardown
    [Documentation]    Closes the Import image dialog (if present) and resets the global variables
    [Arguments]    ${orig_url}
    ${is_modal}=  Is Generic Modal Displayed
    IF  ${is_modal} == ${TRUE}
      Click Button  ${GENERIC_CANCEL_BTN_XP}
    END
    ${IMG_URL}=  Set Variable  ${orig_url}
    Set Global Variable  ${IMG_URL}  ${IMG_URL}
    Reset Image Name

Server Cleanup
    [Documentation]  helper keyword to clean up JL server
    Clean Up Server
    Stop JupyterLab Notebook Server

Create Custom Image
    [Documentation]    Imports a custom ImageStream via UI
    ${curr_date} =  Get Time  year month day hour min sec
    ${curr_date} =  Catenate  SEPARATOR=  @{curr_date}

    # Create a unique notebook name for this test run
    ${IMG_NAME} =  Catenate  ${IMG_NAME}  ${curr_date}
    Set Global Variable  ${IMG_NAME}  ${IMG_NAME}
    Import New Custom Image    ${IMG_URL}     ${IMG_NAME}    ${IMG_DESCRIPTION}
    ...    software=${IMG_SOFTWARE}    packages=${IMG_PACKAGES}

Get ImageStream Metadata And Check Name
    [Documentation]    Gets the metadata of an ImageStream and checks name of the image
    ${get_metadata} =    OpenShiftLibrary.Oc Get    kind=ImageStream    label_selector=app.kubernetes.io/created-by=byon
    ...    namespace=${APPLICATIONS_NAMESPACE}
    FOR     ${imagestream}    IN    @{get_metadata}
      ${image_name} =    Evaluate    $imagestream['metadata']['annotations']['opendatahub.io/notebook-image-name']
      Exit For Loop If    '${image_name}' == '${IMG_NAME}'
    END
    Should Be Equal    ${image_name}    ${IMG_NAME}
    ${IMAGESTREAM_NAME} =   Set Variable    ${imagestream}[metadata][name]
    ${IMAGESTREAM_NAME} =   Set Global Variable    ${IMAGESTREAM_NAME}

Reset Image Name
    [Documentation]    Helper to reset the global variable img name to default value
    ${IMG_NAME} =  Set Variable  custom-test-image
    Set Global Variable  ${IMG_NAME}  ${IMG_NAME}

Get Standard Data Science Local Registry URL
    [Documentation]    Fetches the local URL for the SDS image
    ${registry} =    Run    oc get imagestream s2i-generic-data-science-notebook -n ${APPLICATIONS_NAMESPACE} -o json | jq '.status.dockerImageRepository' | sed 's/"//g'  # robocop: disable
    ${tag} =    Run    oc get imagestream s2i-generic-data-science-notebook -n ${APPLICATIONS_NAMESPACE} -o json | jq '.status.tags[-1].tag' | sed 's/"//g'  # robocop: disable
    RETURN    ${registry}:${tag}
