# OWASP ZAP Security Scan Pipeline using Azure DevOps and Azure Container Instances

This repository contains an Azure DevOps pipeline that automates OWASP ZAP security scanning using Azure Container Instances (ACI). The pipeline allows you to perform both **baseline** and **full** scans on a target website, with the option to update the OWASP ZAP Docker image in your Azure Container Registry (ACR).

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Pipeline Structure](#pipeline-structure)
- [Setup Instructions](#setup-instructions)
- [Usage](#usage)
- [Pipeline Parameters](#pipeline-parameters)
- [Variable Group Configuration](#variable-group-configuration)
- [Understanding the Pipeline Steps](#understanding-the-pipeline-steps)
- [Examples](#Examples)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Overview

OWASP ZAP (Zed Attack Proxy) is an open-source web application security scanner. This pipeline automates the process of running OWASP ZAP scans against a target website using Azure DevOps and Azure Container Instances.

By leveraging Azure Container Instances, the pipeline runs the OWASP ZAP Docker image in a scalable and cost-effective manner without the need to manage infrastructure.

---

## Features

- **Baseline and Full Scans**: Choose between a quick baseline scan or a comprehensive full scan.
- **Dynamic Image Update**: Optionally update the OWASP ZAP Docker image in your ACR.
- **Azure Integration**: Uses Azure Container Instances and Azure Storage for scalable execution and storage of scan reports.
- **Automated Report Processing**: Converts the OWASP ZAP XML report to NUnit format and publishes test results in Azure DevOps.
- **Configurable Parameters**: Easily configure the target URL, scan type, and image update preference.

---

## Prerequisites

Before setting up the pipeline, ensure you have the following:

- **Azure Subscription**: Access to an Azure subscription with permissions to create resources.
- **Azure DevOps Account**: An Azure DevOps organization and project.
- **Azure Service Connection**: A service connection in Azure DevOps to your Azure subscription.
- **Azure Container Registry (ACR)**: An ACR instance to store the OWASP ZAP Docker image.
- **Variable Group**: An Azure DevOps variable group named `zap-group` containing required variables (detailed below).
- **Git Repository**: A Git repository in Azure DevOps or GitHub to store the pipeline YAML and associated files.

---

## Pipeline Structure

The pipeline consists of two main stages:

1. **PrepareACR** (Optional):
   - Logs into ACR.
   - Pulls the latest OWASP ZAP Docker image and pushes it to your ACR.
   - Controlled by the `updateImage` parameter.

2. **SecurityScan**:
   - Creates Azure resources (Resource Group, Storage Account, File Share).
   - Deploys an Azure Container Instance running OWASP ZAP.
   - Waits for the scan to complete.
   - Downloads the scan report from Azure File Share.
   - Converts the report to NUnit format.
   - Publishes test results in Azure DevOps.
   - Cleans up Azure resources.

---

## Setup Instructions

### 1. Clone the Repository

Clone this repository to your local machine:

```bash
git clone https://github.com/your-username/your-repo.git
```
## Configure the Variable Group in Azure DevOps

Create a variable group named `zap-group` in your Azure DevOps project with the following variables:

| Variable Name              | Description                                                                                 |
|----------------------------|---------------------------------------------------------------------------------------------|
| `AZURE_SERVICE_CONNECTION`  | Name of your Azure service connection in Azure DevOps.                                      |
| `ACR_NAME`                  | Name of your Azure Container Registry instance.                                             |
| `ACR_IMAGE`                 | Name of the Docker image in ACR (e.g., `owaspzap`).                                         |
| `ACR_IMAGE_TAG`             | Tag for the Docker image (e.g., `latest`).                                                  |
| `ACI_LOCATION`              | Azure region for deploying resources (e.g., `eastus`).                                      |
| `ACI_RESOURCE_GROUP`        | Name for the Resource Group to be created.                                                  |
| `ACI_STORAGE_ACCOUNT_NAME`  | Name for the Storage Account to be created.                                                 |
| `ACI_SHARE_NAME`            | Name for the File Share to be created.                                                      |
| `ACI_INSTANCE_NAME`         | Name for the Azure Container Instance.                                                      |
| `ACR_PASSWORD`              | Password for accessing ACR (can be retrieved via `az acr credential show`).                 |


### 4. Ensure Required Files Are in Place

- **OWASPToNUnit3.xslt**: 

   Ensure that the `OWASPToNUnit3.xslt` file is placed in the root directory of your repository. This XSLT file is necessary for converting the OWASP ZAP XML scan report into NUnit format, which is compatible with Azure DevOps Test Results.

   The script itself is fairly simple, but it relies on the template which can be found here: [OWASPToNUnit3.xslt Template](https://dev.azure.com/francislacroix/_git/CodeShare?path=%2FOWASPBlog%2FOWASPToNUnit3.xslt).

   Make sure the XSLT file is included in your repository so that the pipeline can access it during execution.

## Usage

When running the pipeline, you can configure the parameters to customize the scan:

1. **Target Site URL for OWASP ZAP Scan** (`targetScan`): The URL of the website you want to scan.
2. **Type of OWASP ZAP Scan** (`scanType`): Choose between `baseline` and `full`.
3. **Update OWASP ZAP Image?** (`updateImage`): Set to `true` to update the Docker image in ACR; otherwise, set to `false`.

### Running the Pipeline

1. Navigate to your pipeline in Azure DevOps.
2. Click **Run pipeline**.
3. Configure the parameters as needed.
4. Click **Run** to start the pipeline.

---

## Pipeline Parameters

| Parameter     | Type    | Default Value                       | Description                                                   |
|---------------|---------|-------------------------------------|---------------------------------------------------------------|
| `targetScan`  | String  | `https://juice-shop.herokuapp.com/` | The URL of the target site to scan with OWASP ZAP.            |
| `scanType`    | String  | `baseline`                          | The type of scan to perform: `baseline` or `full`.            |
| `updateImage` | Boolean | `false`                             | Whether to update the OWASP ZAP image in ACR before scanning. |

---

## Variable Group Configuration

Ensure the `zap-group` variable group contains the following variables:

- **Azure Connection and Registry Details**:
  - `AZURE_SERVICE_CONNECTION`: Name of the Azure service connection.
  - `ACR_NAME`: Name of the Azure Container Registry.
  - `ACR_IMAGE`: Docker image name in ACR.
  - `ACR_IMAGE_TAG`: Docker image tag (e.g., `latest`).
  - `ACR_PASSWORD`: ACR password or access key.

- **Azure Resource Configuration**:
  - `ACI_LOCATION`: Azure region for resource deployment.
  - `ACI_RESOURCE_GROUP`: Name for the Resource Group.
  - `ACI_STORAGE_ACCOUNT_NAME`: Name for the Storage Account.
  - `ACI_SHARE_NAME`: Name for the File Share.
  - `ACI_INSTANCE_NAME`: Name for the Azure Container Instance.

---

## Understanding the Pipeline Steps

### **PrepareACR Stage**

- **Conditionally Executed**: Runs only if `updateImage` is `true`.
- **Tasks**:
  - Logs into ACR.
  - Pulls the latest OWASP ZAP Docker image (`owasp/zap2docker-weekly`).
  - Tags and pushes the image to your ACR.

### **SecurityScan Stage**

- **Independent Execution**: Runs regardless of the `updateImage` parameter.
- **Steps**:
  1. **Checkout Code**: Ensures the repository code is available during the pipeline.
  2. **Create Azure Resources**: Resource Group, Storage Account, and File Share.
  3. **Deploy ACI with OWASP ZAP**:
     - Sets the scan command based on `scanType` (`zap-baseline.py` or `zap-full-scan.py`).
     - Creates the container instance with necessary configurations.
  4. **Wait for Scan Completion**:
     - Uses `az container wait` to wait for the container to reach the `Terminated` state.
     - Checks the exit code to determine if the scan was successful.
  5. **Download Scan Report**:
     - Retrieves the OWASP ZAP report from the Azure File Share.
  6. **Convert Report to NUnit Format**:
     - Uses PowerShell to transform the XML report using the XSLT file.
  7. **Publish Test Results**:
     - Publishes the converted report to Azure DevOps Test Results.
  8. **Cleanup**:
     - Deletes the Azure Container Instance.

---
## Examples

Below is an example of an OWASP ZAP security scan report that is generated and published through the pipeline:

*Sample OWASP ZAP security scan report*
![image](https://github.com/user-attachments/assets/035f2e99-71e4-4eba-b1b5-c3620a84818d)

You can view a detailed example report generated by the OWASP ZAP scan in the pipeline. This report highlights the security vulnerabilities found during the scan, categorized by severity and providing actionable insights.

---
## Troubleshooting

### Common Issues and Solutions

#### 1. **OWASPToNUnit3.xslt Not Found**

- **Error Message**:

```
Exception calling “Load” with “1” argument(s): “Could not find a part of the path ‘…/OWASPToNUnit3.xslt’.”
```
- **Solution**:
- Ensure the `OWASPToNUnit3.xslt` file is in the correct path (`$(System.DefaultWorkingDirectory)/OWASPToNUnit3.xslt`).
- Confirm that the file is included in the repository and checked out during the pipeline.

#### 2. **SecurityScan Stage Skipped**

- **Cause**:
- Implicit dependencies causing the stage to be skipped when the previous stage is skipped.
- **Solution**:
- Add `dependsOn: []` to the `SecurityScan` stage to ensure it runs independently.

#### 3. **Image Not Found in ACR**

- **Cause**:
- The OWASP ZAP image does not exist in ACR when `updateImage` is `false`.
- **Solution**:
- Run the pipeline once with `updateImage` set to `true` to populate ACR with the image.
- Alternatively, add a check in the pipeline to verify the image exists before proceeding.

#### 4. **Container Creation Failures**

- **Solution**:
- Ensure all variables in the variable group are correctly configured.
- Verify that the Azure service connection has the necessary permissions.

---

## Contributing

Contributions are welcome! If you'd like to improve this pipeline or fix any issues, please follow these steps:

1. Fork the repository.
2. Create a new branch:
 ```bash
 git checkout -b feature/YourFeature
```
- **Solution**:
- Ensure the `OWASPToNUnit3.xslt` file is in the correct path (`$(System.DefaultWorkingDirectory)/OWASPToNUnit3.xslt`).
- Confirm that the file is included in the repository and checked out during the pipeline.

#### 2. **SecurityScan Stage Skipped**

- **Cause**:
- Implicit dependencies causing the stage to be skipped when the previous stage is skipped.
- **Solution**:
- Add `dependsOn: []` to the `SecurityScan` stage to ensure it runs independently.

#### 3. **Image Not Found in ACR**

- **Cause**:
- The OWASP ZAP image does not exist in ACR when `updateImage` is `false`.
- **Solution**:
- Run the pipeline once with `updateImage` set to `true` to populate ACR with the image.
- Alternatively, add a check in the pipeline to verify the image exists before proceeding.

#### 4. **Container Creation Failures**

- **Solution**:
- Ensure all variables in the variable group are correctly configured.
- Verify that the Azure service connection has the necessary permissions.

---
## Contributing

Contributions are welcome! If you'd like to improve this pipeline or fix any issues, Happy Zapping ⚡️

---

## Original Solution

This solution is based on the original implementation detailed in the blog post:  
[Azure DevOps Pipelines: Leveraging OWASP ZAP in the Release Pipeline](https://devblogs.microsoft.com/premier-developer/azure-devops-pipelines-leveraging-owasp-zap-in-the-release-pipeline/).

The blog provides a great foundation for integrating OWASP ZAP with Azure DevOps pipelines, and this implementation expands on it to add more features and flexibility.

