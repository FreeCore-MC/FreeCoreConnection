$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$jdk = 'C:\Program Files\Java\jdk-25.0.4\bin'
$velocity = 'C:\MCSManager\daemon\data\InstanceData\FreeCore-Proxy\velocity.jar'
$decoder = 'C:\JavaProgram\FreeCoreAgent\src\main\java\io\github\freecoreagent\tool\ConnectionSample.java'
$version = '1.0.2-main-aliases-candidate'
$buildRoot = Join-Path $root ('build\candidate-' + [guid]::NewGuid().ToString('N'))
$classes = Join-Path $buildRoot 'classes'
$tests = Join-Path $buildRoot 'tests'
New-Item -ItemType Directory -Path $classes,$tests -Force | Out-Null
$sources = Get-ChildItem -LiteralPath (Join-Path $root 'src') -Recurse -Filter '*.java' | Sort-Object FullName | Select-Object -ExpandProperty FullName
& (Join-Path $jdk 'javac.exe') -encoding UTF-8 -cp $velocity -d $classes $sources
if ($LASTEXITCODE -ne 0) { throw 'Proxy compile failed' }
$descriptor = Get-Content -LiteralPath (Join-Path $root 'velocity-plugin.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($descriptor.version -ne '1.0.0') { throw 'Unexpected source descriptor version' }
$descriptor.version = $version
[System.IO.File]::WriteAllText((Join-Path $classes 'velocity-plugin.json'), ($descriptor | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
$artifact = Join-Path $buildRoot "freecore-connection-$version.jar"
& (Join-Path $jdk 'jar.exe') --create --file $artifact --date '2026-10-30T00:00:00Z' -C $classes .
if ($LASTEXITCODE -ne 0) { throw 'Proxy packaging failed' }
$testSources = Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Filter '*.java' | Select-Object -ExpandProperty FullName
& (Join-Path $jdk 'javac.exe') -encoding UTF-8 -cp "$artifact;$velocity" -d $tests $testSources $decoder
if ($LASTEXITCODE -ne 0) { throw 'Proxy test compile failed' }
foreach ($name in @('RouteLabelsTest','ChannelGuardTest','ScheduledEmissionTest')) {
    & (Join-Path $jdk 'java.exe') -cp "$artifact;$tests;$velocity" "com.freecore.connection.$name"
    if ($LASTEXITCODE -ne 0) { throw "Proxy test failed: $name" }
}
& (Join-Path $jdk 'java.exe') -cp "$artifact;$tests;$velocity" com.freecore.connection.ArtifactBoundaryTest $artifact $version
if ($LASTEXITCODE -ne 0) { throw 'Proxy artifact boundary failed' }
$inputs = @($sources) + @($decoder, (Join-Path $root 'velocity-plugin.json'))
$hashes = @($inputs | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash} })
$report = [ordered]@{pass=$true;version=$version;artifact=$artifact;sha256=(Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash;activated=$false;productionPluginCopies=0;velocityApiSha256=(Get-FileHash -LiteralPath $velocity -Algorithm SHA256).Hash;inputs=$hashes;tests=@('RouteLabelsTest','ChannelGuardTest','ScheduledEmissionTest','ArtifactBoundaryTest')}
$reportPath = Join-Path $buildRoot 'build-evidence.json'
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding utf8
[pscustomobject]@{pass=$true;artifact=$artifact;sha256=$report.sha256;evidence=$reportPath;activated=$false} | ConvertTo-Json -Compress
