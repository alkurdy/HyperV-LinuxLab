function New-ISO9660Image {
    <#
    .SYNOPSIS
        Generates a standards-compliant ISO 9660 filesystem image in pure PowerShell.
    .DESCRIPTION
        Constructs system area, Primary Volume Descriptor (PVD), volume descriptor terminator,
        root directory table, and sector-aligned data blocks without external tooling or COM dependencies.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$VolumeId = "cidata",

        [Parameter(Mandatory = $true)]
        [hashtable]$Files
    )

    $sectorSize = 2048
    $stream = New-Object System.IO.MemoryStream

    try {
        # 16 system sectors (32,768 bytes of 0x00)
        $systemArea = New-Object byte[] (16 * $sectorSize)
        $stream.Write($systemArea, 0, $systemArea.Length)

        # Process file payloads
        $fileData = @{}
        $totalFileSectors = 0
        foreach ($k in $Files.Keys) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Files[$k])
            $sectors = [math]::Ceiling($bytes.Length / $sectorSize)
            if ($sectors -eq 0) { $sectors = 1 }
            $fileData[$k] = @{
                Bytes   = $bytes
                Sectors = $sectors
                Length  = $bytes.Length
            }
            $totalFileSectors += $sectors
        }

        # Sector assignment
        $rootSector = 18
        $currentFileSector = 19
        foreach ($k in $Files.Keys) {
            $fileData[$k]["Sector"] = $currentFileSector
            $currentFileSector += $fileData[$k]["Sectors"]
        }
        $totalSectors = $currentFileSector

        # Sector 16: Primary Volume Descriptor (PVD)
        $pvd = New-Object byte[] $sectorSize
        $pvd[0] = 0x01 # Type: PVD
        [System.Text.Encoding]::ASCII.GetBytes("CD001").CopyTo($pvd, 1)
        $pvd[6] = 0x01 # Version

        # System & Volume Identifiers (32 bytes padded)
        [System.Text.Encoding]::ASCII.GetBytes("HYPERV LAB".PadRight(32)).CopyTo($pvd, 8)
        [System.Text.Encoding]::ASCII.GetBytes($VolumeId.PadRight(32)).CopyTo($pvd, 40)

        # Volume Space Size (LSB at 80, MSB at 84)
        [BitConverter]::GetBytes([uint32]$totalSectors).CopyTo($pvd, 80)
        $revTotal = [BitConverter]::GetBytes([uint32]$totalSectors)
        [Array]::Reverse($revTotal)
        $revTotal.CopyTo($pvd, 84)

        # Logical Block Size (2048 bytes)
        [BitConverter]::GetBytes([uint16]2048).CopyTo($pvd, 128)
        $revBlock = [BitConverter]::GetBytes([uint16]2048)
        [Array]::Reverse($revBlock)
        $revBlock.CopyTo($pvd, 130)

        # Root Directory Record in PVD (offset 156)
        $rootRecord = New-Object byte[] 34
        $rootRecord[0] = 34 # Length
        [BitConverter]::GetBytes([uint32]$rootSector).CopyTo($rootRecord, 2)
        $revRootSec = [BitConverter]::GetBytes([uint32]$rootSector)
        [Array]::Reverse($revRootSec)
        $revRootSec.CopyTo($rootRecord, 6)

        [BitConverter]::GetBytes([uint32]2048).CopyTo($rootRecord, 10)
        $revRootLen = [BitConverter]::GetBytes([uint32]2048)
        [Array]::Reverse($revRootLen)
        $revRootLen.CopyTo($rootRecord, 14)

        $rootRecord[25] = 0x02 # Directory flag
        $rootRecord[32] = 1
        $rootRecord[33] = 0x00 # Root identifier
        $rootRecord.CopyTo($pvd, 156)

        $pvd[881] = 0x01 # File structure version
        $stream.Write($pvd, 0, $sectorSize)

        # Sector 17: Volume Descriptor Set Terminator
        $term = New-Object byte[] $sectorSize
        $term[0] = 0xFF
        [System.Text.Encoding]::ASCII.GetBytes("CD001").CopyTo($term, 1)
        $term[6] = 0x01
        $stream.Write($term, 0, $sectorSize)

        # Sector 18: Root Directory Table
        $rootDir = New-Object byte[] $sectorSize
        $offset = 0

        # Entry 1: Current directory "."
        $dot = New-Object byte[] 34
        $dot[0] = 34
        [BitConverter]::GetBytes([uint32]$rootSector).CopyTo($dot, 2)
        $rev = [BitConverter]::GetBytes([uint32]$rootSector); [Array]::Reverse($rev); $rev.CopyTo($dot, 6)
        [BitConverter]::GetBytes([uint32]2048).CopyTo($dot, 10)
        $rev = [BitConverter]::GetBytes([uint32]2048); [Array]::Reverse($rev); $rev.CopyTo($dot, 14)
        $dot[25] = 0x02
        $dot[32] = 1
        $dot[33] = 0x00
        $dot.CopyTo($rootDir, $offset)
        $offset += 34

        # Entry 2: Parent directory ".."
        $dotdot = New-Object byte[] 34
        $dotdot[0] = 34
        [BitConverter]::GetBytes([uint32]$rootSector).CopyTo($dotdot, 2)
        $rev = [BitConverter]::GetBytes([uint32]$rootSector); [Array]::Reverse($rev); $rev.CopyTo($dotdot, 6)
        [BitConverter]::GetBytes([uint32]2048).CopyTo($dotdot, 10)
        $rev = [BitConverter]::GetBytes([uint32]2048); [Array]::Reverse($rev); $rev.CopyTo($dotdot, 14)
        $dotdot[25] = 0x02
        $dotdot[32] = 1
        $dotdot[33] = 0x01
        $dotdot.CopyTo($rootDir, $offset)
        $offset += 34

        # File Directory Entries
        foreach ($k in $Files.Keys) {
            $fNameBytes = [System.Text.Encoding]::ASCII.GetBytes($k)
            $recLen = 33 + $fNameBytes.Length
            if ($recLen % 2 -ne 0) { $recLen++ }
            $entry = New-Object byte[] $recLen
            $entry[0] = [byte]$recLen

            $sec = [uint32]$fileData[$k]["Sector"]
            $len = [uint32]$fileData[$k]["Length"]
            [BitConverter]::GetBytes($sec).CopyTo($entry, 2)
            $rev = [BitConverter]::GetBytes($sec); [Array]::Reverse($rev); $rev.CopyTo($entry, 6)
            [BitConverter]::GetBytes($len).CopyTo($entry, 10)
            $rev = [BitConverter]::GetBytes($len); [Array]::Reverse($rev); $rev.CopyTo($entry, 14)

            $entry[25] = 0x00 # Regular file
            $entry[32] = [byte]$fNameBytes.Length
            $fNameBytes.CopyTo($entry, 33)

            $entry.CopyTo($rootDir, $offset)
            $offset += $recLen
        }
        $stream.Write($rootDir, 0, $sectorSize)

        # File Payload Sectors (padded to 2048-byte boundaries)
        foreach ($k in $Files.Keys) {
            $b = $fileData[$k]["Bytes"]
            $stream.Write($b, 0, $b.Length)
            $remainder = $b.Length % $sectorSize
            if ($remainder -ne 0) {
                $pad = New-Object byte[] ($sectorSize - $remainder)
                $stream.Write($pad, 0, $pad.Length)
            }
        }

        # Flush to target file
        $parentDir = Split-Path -Parent $Path
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        if ($PSCmdlet.ShouldProcess($Path, "Create ISO 9660 image")) {
            [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
        }
    }
    finally {
        $stream.Dispose()
    }
}
