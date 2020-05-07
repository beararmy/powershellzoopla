## NOTES
# https://jsonschema.net/home <-- really useful for building the schema from a json results block
# https://developer.zoopla.co.uk/docs <-- API Documentation (token approval is sloooow)
# Input parameters for query (from https://developer.zoopla.co.uk/docs/read/Property_listings)

# Pull in my JSON config
$config = Get-Content -Path .\config.json -Raw | ConvertFrom-Json

# TEST / SAMPLE DATA
# hashtable, Postcode, radius (miles)
$searchLocations = @{
    "HP7 9PG"  = "15"
    "BS11 9EA" = "10"
    "SP10 5AF" = "10"
}
$staticInputParams = @{
    listing_status = "sale"
    minimum_price  = "100000"
    maximum_price  = "325000"
    minimum_beds   = "3"
    property_type  = "houses"
    new_homes      = "true"
    page_size      = "100"
}
$propertyToPass = @{
    details_url         = "https://www.zoopla.co.uk/for-sale/details/53059231?search_identifier=bf48d80f2d2e2e60c125170fe380aa89"
    num_bedrooms        = "4"
    num_recepts         = "3"
    price               = "£250,000"
    image_354_255_url   = "https://lid.zoocdn.com/645/430/40c11e373f96ae85d07fff94f124e21f8ecc8e8d.jpg"
    displayable_address = "Calne"
    last_published_date = "2020-01-01 11:22:33"
} 
$propertyToNotify = $propertyToPass | ConvertTo-Json
function New-ZooplaQueryString {
    param (
        [parameter(Mandatory = $true)]
        [ValidateLength(6, 8)]
        [ValidatePattern("^([A-Za-z][A-Ha-hJ-Yj-y]?[0-9][A-Za-z0-9]? ?[0-9][A-Za-z]{2}|[Gg][Ii][Rr] ?0[Aa]{2})$")]
        [string]$postcode,
        
        [parameter(Mandatory = $true)]
        [ValidateRange(0.1, 40)]
        [single]$radius,

        [parameter(Mandatory = $true)]
        [object]$staticInputParams
    )
    $postcodeForAPI = $postcode.Replace(" ", "+")
    $string = "?api_key=" + $config.zoopla.apikey + "&postcode=" + $postcodeForAPI + "&radius=" + $radius
    foreach ($staticparam in $staticInputParams.GetEnumerator()) {
        $string = $string + "&" + $staticparam.Name + "=" + $staticparam.Value
    }
    $qryString = $config.zoopla.URIbase + $config.zoopla.URItypepage + $string
    return $qryString
}
function Update-ZooplaResult {
    param (
        $result
    )
    
}
function Add-IntoEventHub {
    param (
        [object]$propertyToNotify
    )

    # Create hashed SAS token from SAS key
    [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
    $Expires = ([DateTimeOffset]::Now.ToUnixTimeSeconds()) + 300 # Token expires now+300
    $SignatureString = [System.Web.HttpUtility]::UrlEncode($config.eventhub.eventhuburi) + "`n" + [string]$Expires
    $HMAC = New-Object System.Security.Cryptography.HMACSHA256
    $HMAC.key = [Text.Encoding]::ASCII.GetBytes($config.eventhub.saskey)
    $Signature = $HMAC.ComputeHash([Text.Encoding]::ASCII.GetBytes($SignatureString))
    $Signature = [Convert]::ToBase64String($Signature)
    $SASToken = "SharedAccessSignature sr=" + [System.Web.HttpUtility]::UrlEncode($config.eventhub.eventhuburi) + "&sig=" + [System.Web.HttpUtility]::UrlEncode($Signature) + "&se=" + $Expires + "&skn=" + $config.eventhub.sasname

    # Set the headers and make the POST
    $parsedURIEventHub = "https://" + $config.eventhub.servicebusNamespace + ".servicebus.windows.net/" + $config.eventhub.eventhubpath + "/messages"
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $SASToken)
    $headers.Add("Content-Type", 'application/atom+xml;type=entry;charset=utf-8')
    $headers.Add("Host", 'stefzoopla.servicebus.windows.net')
    Invoke-RestMethod -Uri $parsedURIEventHub -Method POST -Body $json -Headers $headers
}

function Calculate-SquareMeterage {
    param (
        
    )
    
}


# Pull data from zoopla
$queries = foreach ($postcode in $searchLocations.GetEnumerator()) {
    New-ZooplaQueryString -postcode  $postcode.Key -radius $postcode.Value -staticInputParams $staticInputParams
}

# Make-a web-a request-a :italianhand:
foreach ($query in $queries) {
    Invoke-RestMethod -Method GET -Uri $query
}

# Clean up the dodgy Zoopla data
foreach ($result in $results) {
    Update-ZooplaResult -inputResult $result
}

# Clean up the dodgy Zoopla data
foreach ($property in $propertyToNotify) {
    Add-IntoEventHub -propertyToNotify $property
}