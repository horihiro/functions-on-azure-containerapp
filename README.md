# Azure Functions on Azure Container Apps
![image](https://user-images.githubusercontent.com/4566555/219943288-617fb65f-d2af-4208-976d-24b866ef9783.png)

## Deployed resources
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fhorihiro%2Ffunctions-on-azure-containerapp%2Fjson_template%2Fmain.json)

The above deployment button generates the following resources

  - Storage Account:  
    File storage to store function code and be mounted as `/home/site/wwwroot` of containers
  - Container App:  
    Container host for Azure Functions image `mcr.microsoft.com/azure-functions/${WORKER_RUNTIME_LANGUAGE}`
  - Container App Environment:  
    Managed environment for the Container App and it can be deployed in VNET also.
  - Application Insights:  
    Destination of logs from Azure Function host process in the container.
  - Log Analytics:
    Log store for the Container App and Azure Functions host process in the container.

![resourceGroupName](https://user-images.githubusercontent.com/4566555/220277151-3d122b8c-c265-4ab0-8a3e-986fbbc1f1f0.png)
