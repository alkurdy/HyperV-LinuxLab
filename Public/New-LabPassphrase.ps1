function New-LabPassphrase {
    <#
    .SYNOPSIS
        Generates a memorable, human-friendly passphrase for lab VMs and user accounts.
    .DESCRIPTION
        Generates a simple, readable Diceware-style passphrase combining adjectives, nouns,
        and numbers (e.g., 'Swift-Falcon-42'). Each spin-up creates a distinct passphrase
        that satisfies Linux complexity requirements without character ambiguities.
    .PARAMETER WordCount
        Number of words in the passphrase (default: 2).
    .PARAMETER Separator
        Delimiter between words (default: '-').
    .PARAMETER IncludeNumber
        Whether to append a random 2-digit number (10-99). Default is $true.
    .PARAMETER AsSecureString
        Returns the result as a System.Security.SecureString object.
    .EXAMPLE
        New-LabPassphrase
        # Returns e.g. "Swift-Falcon-42"
    .EXAMPLE
        New-LabPassphrase -WordCount 3 -Separator "_"
        # Returns e.g. "Cosmic_Amber_Otter_73"
    .EXAMPLE
        $sec = New-LabPassphrase -AsSecureString
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType([string], [System.Security.SecureString])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 6)]
        [int]$WordCount = 2,

        [Parameter(Mandatory = $false)]
        [string]$Separator = "-",

        [Parameter(Mandatory = $false)]
        [bool]$IncludeNumber = $true,

        [Parameter(Mandatory = $false)]
        [switch]$AsSecureString
    )

    $adjectives = @(
        "Amber", "Azure", "Brave", "Bright", "Calm", "Cedar", "Clever", "Cobalt",
        "Cosmic", "Crisp", "Dawn", "Delta", "Eager", "Fair", "Frost", "Golden",
        "Grand", "Green", "Happy", "Jade", "Keen", "Lunar", "Magic", "Mellow",
        "Mystic", "Neon", "Noble", "Nova", "Ocean", "Opal", "Polar", "Prime",
        "Quick", "Quiet", "Rapid", "Ruby", "Rustic", "Sage", "Shadow", "Sharp",
        "Silent", "Silver", "Solar", "Spark", "Spring", "Star", "Storm", "Sunny",
        "Swift", "Teal", "Topaz", "True", "Velvet", "Vivid", "Warm", "Wild",
        "Wise", "Zen"
    )

    $nouns = @(
        "Anchor", "Badger", "Beacon", "Bear", "Beaver", "Bison", "Breeze", "Canyon",
        "Castle", "Cliff", "Cloud", "Clover", "Comet", "Coral", "Coyote", "Crag",
        "Crane", "Creek", "Dolphin", "Dragon", "Eagle", "Falcon", "Fern", "Finch",
        "Forest", "Fox", "Geyser", "Glacier", "Gull", "Harbor", "Hawk", "Heron",
        "Island", "Jaguar", "Jay", "Kestrel", "Lagoon", "Lark", "Lynx", "Meadow",
        "Moose", "Mountain", "Nebula", "Otter", "Owl", "Panda", "Peak", "Pelican",
        "Penguin", "Pine", "Planet", "Pond", "Quail", "Rabbit", "Raven", "Reef",
        "Ridge", "River", "Robin", "Rocket", "Salmon", "Sea", "Sierra", "Sky",
        "Sparrow", "Stone", "Stream", "Summit", "Swan", "Tiger", "Timber", "Tower",
        "Trail", "Trout", "Tulip", "Valley", "Viper", "Wave", "Willow", "Wolf", "Wren"
    )

    $selectedWords = [System.Collections.Generic.List[string]]::new()

    $rngType = [System.Security.Cryptography.RandomNumberGenerator]
    $getInt32Method = $rngType.GetMethods([System.Reflection.BindingFlags]'Public,Static') |
        Where-Object { $_.Name -eq 'GetInt32' -and $_.GetParameters().Count -eq 2 } |
        Select-Object -First 1

    $getSecureRandomInt = {
        param(
            [Parameter(Mandatory = $true)]
            [int]$MinInclusive,
            [Parameter(Mandatory = $true)]
            [int]$MaxExclusive
        )

        if ($MaxExclusive -le $MinInclusive) {
            throw "MaxExclusive must be greater than MinInclusive."
        }

        if ($null -ne $getInt32Method) {
            return [System.Security.Cryptography.RandomNumberGenerator]::GetInt32($MinInclusive, $MaxExclusive)
        }

        $range = [uint32]($MaxExclusive - $MinInclusive)
        $limit = [uint32]::MaxValue - ([uint32]::MaxValue % $range)
        $bytes = [byte[]]::new(4)
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

        try {
            do {
                $rng.GetBytes($bytes)
                $value = [BitConverter]::ToUInt32($bytes, 0)
            } while ($value -ge $limit)
        } finally {
            $rng.Dispose()
        }

        return $MinInclusive + [int]($value % $range)
    }

    if ($WordCount -eq 1) {
        $idx = & $getSecureRandomInt 0 $nouns.Count
        $selectedWords.Add($nouns[$idx])
    } else {
        for ($i = 0; $i -lt ($WordCount - 1); $i++) {
            $idx = & $getSecureRandomInt 0 $adjectives.Count
            $selectedWords.Add($adjectives[$idx])
        }
        $nounIdx = & $getSecureRandomInt 0 $nouns.Count
        $selectedWords.Add($nouns[$nounIdx])
    }

    $passphrase = $selectedWords -join $Separator

    if ($IncludeNumber) {
        $num = & $getSecureRandomInt 10 100
        $passphrase = "${passphrase}${Separator}${num}"
    }

    if ($AsSecureString) {
        $sec = [System.Security.SecureString]::new()
        foreach ($c in $passphrase.ToCharArray()) {
            $sec.AppendChar($c)
        }
        $sec.MakeReadOnly()
        return $sec
    }

    return $passphrase
}
