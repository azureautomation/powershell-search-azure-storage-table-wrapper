
<#
.Synopsis
   Searches an Azure Storage Table
.DESCRIPTION
   Searches an Azure Storage Table using segmented queries. That is, results will be streamed down the pipeline as they become available.
.EXAMPLE
   # Retrieve the table rows, project to the given columns, filter by the given filter, and get only the first 12 rows
   Search-AzureStorageTable -TableName $tableName -SelectedColumns Col1, Col2, Col3 -Filter "Col1 eq 'Col1Value'" -First 12 -StorageAccountName $accountName -StorageAccountKey $accountKey 
.EXAMPLE
   # Retrieve the table rows as DynamicTableEntity in which all values are stored in a Properties array. Project to the given columns, filter by the given filter, and get only the first 1200 rows.
   Search-AzureStorageTable -TableName $tableName -SelectedColumns Col1, Col2, Col3 -Filter "Col1 eq 'Col1Value'" -First 1200 -StorageAccountName $accountName -StorageAccountKey $accountKey -DoNotExpandProperties
.EXAMPLE
   # Retrieve all rows in the table using a provided storage context for authentication
   Search-AzureStorageTable -TableName $tableName -AzureStorageContext $ctx
.EXAMPLE
    # Shows how to create filters using the Storage TableQuery functions
    # Create a filter for a DateTime field
    $filterTime = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterConditionForDate("ChangedDateTime", [Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::GreaterThan, $UpdatedSince)

    # Create a filter for a string field
    $filterState = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::GenerateFilterCondition("State", [Microsoft.WindowsAzure.Storage.Table.QueryComparisons]::Equal, "Active")

    # Combine the two filters
    $filter = [Microsoft.WindowsAzure.Storage.Table.TableQuery]::CombineFilters($filterTime, [Microsoft.WindowsAzure.Storage.Table.TableOperators]::And, $filterState)

    Search-AzureStorageTable -TableName $tableName -Filter $filter -AzureStorageContext $ctx
.LINK
    For details on supported Filter formats, see: https://msdn.microsoft.com/en-us/library/azure/ff683669.aspx
#>
function Search-AzureStorageTable
{
    [CmdletBinding(DefaultParameterSetName = "AccountAndKey")]
    [OutputType([object[]])]
    Param
    (
        # The table to pull rows from
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string]
        $TableName,

        # The account that contains the storage table
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName="AccountAndKey")]
        [string]
        $StorageAccountName,

        # The account's key
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName="AccountAndKey")]
        [string]
        $StorageAccountKey,

        # A storage context object to use for authentication
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   ParameterSetName="StorageContext")]
        [Object]
        $AzureStorageContext,

        # A list of columns to select out, this will project out the selected columns and return only those
		[Parameter(ValueFromPipelineByPropertyName=$true)]
        [string[]]
        $SelectedColumns,

        # Take only the first X items
		[Parameter(ValueFromPipelineByPropertyName=$true)]
        [int]
        $First,

        # A filter string to use for server side filtering. For details on supported Filter formats, see: https://msdn.microsoft.com/en-us/library/azure/ff683669.aspx
		[Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]
        $Filter,

        # Disables expanding the returned properties into objects. Without expansion normally you'll receive DynamicTableEntity objects and need to do something like $entities.Properties.PropertyName.PropertyAsObject to get the property values, remove this flag to create flattened PSObjects.
		[Parameter(ValueFromPipelineByPropertyName=$true)]
        [switch]
        $DoNotExpandProperties
    )

    Begin{}
    Process
    {
        if(!$AzureStorageContext)
        {
            #No storage context provided, define the storage context.
            $AzureStorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
        }

        # Get a reference to a table.
        $table = Get-AzureStorageTable -Name $TableName -Context $AzureStorageContext

        # Create a table query.
        $query = New-Object Microsoft.WindowsAzure.Storage.Table.TableQuery

        # Set query filter string
        $query.FilterString = $Filter
        
        if($SelectedColumns)
        {
            # Select only the provided columns
            $query.SelectColumns = $SelectedColumns
        }

        if($First)
        {
            # Take only the first X items
            $query.TakeCount = $First
        }

        Write-Verbose "Retrieving $First entities from $TableName with filter '$Filter' and select columns '$SelectedColumns'"

		# Initalize the continuation token
        $continuationToken = $null

        #region Execute query in a segmented fashion so later functions in the pipeline can get their work started while the query continues
        do
        {
            # Execute the query
            $result = $table.CloudTable.ExecuteQuerySegmented($query, $continuationToken, $null, $null)

            # Save the returned continuation token
            $continuationToken = $result.ContinuationToken

            $entities = $result.Results

            if($First)
            {
                # Reduce the number of entities to take by the number of entities retrieved
                $numEntities = $entities.Count
                $First -= $numEntities

                Write-Verbose "Entities retrieved $numEntities, entities left to retrieve $First"
                if($First -gt 0)
                {
                    # Set the new take count
                    $query.TakeCount = $First
                }
                else
                {
                    # No more entities to take, drop the continuation token
                    $continuationToken = $null
                }
            }

            if($DoNotExpandProperties)
            {
                # Property expansion not requested, just output each entity
                foreach ($entity in $entities)
                {
                    Write-Output $entity
                }
            }
            else
            {
                # Property expansion requested, expand the properties into a flat PSCustom object
                foreach ($entity in $entities)
                {
                    $expandedEntity = @{}
                    $expandedEntity["PartitionKey"] = $entity.PartitionKey
                    $expandedEntity["RowKey"] = $entity.RowKey
                    $expandedEntity["Timestamp"] = $entity.Timestamp
                    $expandedEntity["ETag"] = $entity.ETag
                
                    foreach ($property in $entity.Properties)
                    {
                        foreach($key in $property.Keys)
                        {
                            $expandedEntity[$key] = $property[$key].PropertyAsObject
                        }
                    }

                    $psObject = [PSCustomObject]$expandedEntity
                    Write-Output $psObject
                }                
            }
        }
        while ($continuationToken -ne $null) # Continue until there's no continuation token provided
        #endregion
    }
    End{}
}