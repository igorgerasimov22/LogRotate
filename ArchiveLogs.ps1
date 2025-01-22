param(
[Parameter(Position=0, Mandatory=$false)]
[string]$zip="C:\Program Files\7-Zip\7z.exe",
[Parameter(Position=1, Mandatory=$false)]
[string]$extenssion=".7z",
[Parameter(Position=2, Mandatory=$false)]
[string]$BackUp_path="C:\inetpub\logs\LogFiles\W3SVC1\",
[Parameter(Position=3, Mandatory=$false)]
[string]$BackUp_path1="C:\inetpub\logs\LogFiles\W3SVC2\",
[Parameter(Position=4, Mandatory=$false)]
[int]$days=-1,
[Parameter(Position=5, Mandatory=$false)]
[int]$backup_days=-31
)

function Archive-file($file_zip, $file_path, $file_extenssion)
{
    $files = Get-ChildItem $file_path -Include ('*.txt','*.log') -Recurse
    foreach($file in $files)
    {
        if($file.CreationTime -le (Get-Date).AddDays($days))
        {
            $file_name = ($file.LastWriteTime).ToShortDateString()
            $fl=$file.name          
            [array]$arguments = "a","$file_path$file_name$file_extenssion","-t7z","-m0=lzma2","-mx=9","-aoa","-mfb=64","-md=32m","-ms=on", "$file_path$fl"
            & $Zip $arguments 
            Remove-Item -Path "$file_path$fl" -Recurse
        }
    }
}

function Archive-Remove($remove_path)
{
    $files_7z = Get-ChildItem $remove_path -Filter *.7z -Recurse
    foreach($file_7z in $files_7z)
    {
        if($file_7z.CreationTime  -lt (Get-Date).AddDays($backup_days))
        {
            Remove-Item -Path $remove_path$file_7z
        }
    }
}

Archive-file $zip $BackUp_path $extenssion
Archive-Remove $BackUp_path
Archive-file $zip $BackUp_path1 $extenssion
Archive-Remove $BackUp_path1