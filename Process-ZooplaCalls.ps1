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
$rightmoveSearchLocations = @{
    "USERDEFINEDAREA%5E%7B%22polylines%22%3A%22utd%7BHddeQly%40_fBdTe%7CFsnAgn%40rQowDrnAj_A%60%7C%40ykJwhE_gS_dAv_CgDrjD%7B%7BA%7Ci%40kbJaeT_gIoqT~nEqdGhzBnqEvdJuzUdaBmyNg%7B%40whTggKr%7CHscBciGuAqhPslH%7DpCsIwkJ~k%40%7D%7BPtpHjfD%7CiReAvwMs%60_%40jpRem%5DpaFykJ%60_H_fBhrHlvHd%5Cnhg%40ljL%60jUrcOtbVzoIxqT%60dAr%7CDrsAskAbpF%60_EljEfoA%7Bb%40rxGu%7CCbxLjaAjwRnqKuhBtkQngS%60~FliIa%7C%40ztMuy%40t%7BQdwC%60rIvtE%7CmMppGqsCxbGdoQteGvm%60%40inH%60fe%40u%7BA%7C%7DIgtDvX_vB%7BpCeiNe~%5CypO%60l%40czMz%7DBwfCwrWcOivW%7DlU_VyiE%7BxKspDvgBsxDc~MgpPo_%60%40_oAgoIuiEe_B%7BjB%60dJ%7CiGpwTbmAzkSr%7CCfqvAajDahA%7D%60BwzMkaDqF%7B~A~sEoiE%7CRufBsgBmYecEhkCg~Dv%60B%7DiBv%5E%7B%7D%40inCoWa%7DFv%7BAq%7CBs%7BCzLmqFtHaxMf%7DQqhCsiEejMeqd%40j%7DAsdEdiSkrBicV~%7B%40ogJfiAnyCn%7BC%7Bi%40%22%7D%22" = "0.0"
}

$rightmoveStaticInputParams = @{
    channel                    = "BUY"
    minPrice                   = 200000
    maxPrice                   = 325000
    minBedrooms                = 4
    primaryDisplayPropertyType = "houses"
    maxDaysSinceAdded          = 7
    mustHave                   = ""
    dontShow                   = "retirement"
    keywords                   = ""
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
function New-RightmoveQueryString {
    param (
        [parameter(Mandatory = $true)]
        [string]$searchTerm,
        
        [parameter(Mandatory = $true)]
        [ValidateRange(0, 40)]
        [single]$radius,

        [parameter(Mandatory = $true)]
        [object]$rightmoveStaticInputParams
    )
    $string = "?locationIdentifier=" + $searchTerm + "&radius=" + $radius
    foreach ($staticparam in $rightmoveStaticInputParams.GetEnumerator()) {
        $string = $string + "&" + $staticparam.Name + "=" + $staticparam.Value
    }
    $qryString = $config.rightmove.URIbase + $config.rightmove.URItypepage + $string
    return $qryString
}
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

# create query string for zoopla
$queries = foreach ($postcode in $searchLocations.GetEnumerator()) {
    New-ZooplaQueryString -postcode  $postcode.Key -radius $postcode.Value -staticInputParams $staticInputParams
}

# create query string for rightmove
$rightmoveQueries = foreach ($location in $rightmoveSearchLocations.GetEnumerator()) {
    New-RightmoveQueryString -searchTerm $location.Key -radius $location.Value -rightmoveStaticInputParams $rightmoveStaticInputParams
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
