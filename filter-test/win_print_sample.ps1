# run.sh의 sample.ps와 같은 레이아웃을 Windows 프린터로 A4 인쇄한다.
# 좌표는 PostScript 포인트(왼쪽 아래 원점)를 1/100인치(왼쪽 위 원점)로 바꿔 쓴다.
param(
    [string]$Printer = 'J1660-FILE',
    [string]$DocName = 'sample.pdf',
    # 드라이버가 노출하는 해상도 종류: High, Medium, Low, Draft (비우면 드라이버 기본값)
    [string]$Quality = '',
    [switch]$Gray
)
Add-Type -AssemblyName System.Drawing

function P([double]$pt) { [float]($pt * 100 / 72) }
function Top([double]$ptY) { P (842 - $ptY) }

$doc = New-Object System.Drawing.Printing.PrintDocument
$doc.DocumentName = $DocName
$doc.PrinterSettings.PrinterName = $Printer
if (-not $doc.PrinterSettings.IsValid) { throw "printer not found: $Printer" }
$a4 = $doc.PrinterSettings.PaperSizes | Where-Object { $_.Kind -eq 'A4' } | Select-Object -First 1
if ($a4) { $doc.DefaultPageSettings.PaperSize = $a4 }
if ($Quality) {
    $doc.DefaultPageSettings.PrinterResolution = $doc.PrinterSettings.PrinterResolutions |
        Where-Object { "$($_.Kind)" -eq $Quality } | Select-Object -First 1
}
if ($Gray) { $doc.DefaultPageSettings.Color = $false }

$doc.add_PrintPage({
    param($sender, $e)
    $g = $e.Graphics
    $g.PageUnit = [System.Drawing.GraphicsUnit]::Display
    # 여백 오프셋을 없애 용지 기준 좌표로 그린다.
    $g.TranslateTransform(-$e.PageSettings.HardMarginX, -$e.PageSettings.HardMarginY)
    $big = New-Object System.Drawing.Font('Arial', 28, [System.Drawing.GraphicsUnit]::Point)
    $small = New-Object System.Drawing.Font('Arial', 14, [System.Drawing.GraphicsUnit]::Point)
    $g.DrawString('SL-J1660 hpcups test', $big, [System.Drawing.Brushes]::Black, (P 72), (Top 788))
    $g.DrawString('Black text line - 0123456789 ABCDEFG', $small, [System.Drawing.Brushes]::Black, (P 72), (Top 744))
    $g.FillRectangle([System.Drawing.Brushes]::Red,   (P 72),  (Top 680), (P 120), (P 120))
    $g.FillRectangle([System.Drawing.Brushes]::Lime,  (P 212), (Top 680), (P 120), (P 120))
    $g.FillRectangle([System.Drawing.Brushes]::Blue,  (P 352), (Top 680), (P 120), (P 120))
    $g.FillRectangle([System.Drawing.Brushes]::Black, (P 72),  (Top 500), (P 400), (P 100))
    $e.HasMorePages = $false
})
$doc.Print()
