# dont kill me (coolingtool) for using powershell
param ([string]$infile, [float]$scale, [string]$outfile)
[xml]$atlas = Get-Content (Resolve-Path $infile)
$attrs = 'x','y','width','height','frameX','frameY','frameWidth','frameHeight'
$textures = $atlas.SelectNodes("//SubTexture") 
foreach ($texture in $textures) {
    foreach ($attr in $attrs) {
        $value = [float]$texture.GetAttribute($attr)
        # ne means not equal, idk why they didnt make it verbose like everything else or just add !=, fuck you microsoft
        if ($value -ne 0) {
            $texture.SetAttribute($attr, $value * $scale)
        }
    }
}

# whjat the fuck, who did this
$atlas.Save($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outfile))