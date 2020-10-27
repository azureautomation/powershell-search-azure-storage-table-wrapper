PowerShell Search Azure Storage Table Wrapper
=============================================

            
This PowerShell function simplifies using the Azure Storage Table Search facilities described in the [Azure Storage PowerShell Guide](http://azure.microsoft.com/documentation/articles/storage-powershell-guide-full/). It also enables PowerShell pipelining so that functions further down the pipeline can begin processing results while additional entities are downloading. This is accomplished via segmented queries. Each segment will be downloaded and the results
 will be immediately passed down the pipeline before the next segment is downloaded.

Another feature of this function is to optionally flatten the resulting entities to simplify use in other functions. Normally, entities are returned as
[DynamicTableEntity](https://msdn.microsoft.com/library/azure/microsoft.windowsazure.storage.table.dynamictableentity_members.aspx) objects, where the field values are contained in a Properties collection. This nesting means reading those fields requires unpacking from the Properties collection. This function returns values in PSObject format where all the values
 are in a flat object so no unpacking is required.


 


        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
