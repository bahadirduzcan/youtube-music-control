@echo off
setlocal
title YT Music Control - Build and Install

cd /d "%~dp0"

echo ===============================================================
echo   YT MUSIC CONTROL - APK Build and Install
echo ===============================================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
    echo [HATA] Flutter PATH'te bulunamadi.
    echo Cozum: Flutter SDK'yi kurun ve PATH'e ekleyin.
    echo https://docs.flutter.dev/get-started/install/windows
    pause
    exit /b 1
)

echo [1/5] flutter pub get
echo ---------------------------------------------------------------
call flutter pub get
if errorlevel 1 (
    echo.
    echo [HATA] pub get basarisiz oldu.
    pause
    exit /b 1
)
echo.

echo [2/5] Uygulama ikonlari yeniden olusturuluyor
echo ---------------------------------------------------------------
call dart run flutter_launcher_icons
if errorlevel 1 (
    echo.
    echo [UYARI] Ikon olusturma hata verdi - kuruluma devam ediliyor.
)
echo.

echo [3/5] flutter analyze
echo ---------------------------------------------------------------
call flutter analyze --no-fatal-infos --no-fatal-warnings
echo.
echo Warning/info varsa devam edebilir, sadece error build'i durdurur.
echo.

echo [4/5] Release APK build - 1-3 dakika surer
echo ---------------------------------------------------------------
call flutter build apk --release
if errorlevel 1 (
    echo.
    echo [HATA] APK build basarisiz oldu.
    echo Yukaridaki hata mesajini kopyalayip Claude'a iletin.
    pause
    exit /b 1
)
echo.
echo APK hazir: build\app\outputs\flutter-apk\app-release.apk
echo.

echo [5/5] Bagli cihazlar
echo ---------------------------------------------------------------
where adb >nul 2>nul
if not errorlevel 1 (
    echo Bagli Android cihazlar:
    adb devices
    echo.
)

call flutter devices
echo.

set /p INSTALL_NOW=Telefonunuza kurmak ister misiniz? [E/H]:
if /i "%INSTALL_NOW%"=="E" goto :do_install
if /i "%INSTALL_NOW%"=="e" goto :do_install
goto :no_install

:do_install
echo.
where adb >nul 2>nul
if not errorlevel 1 (
    echo Eski surumler kaldiriliyor varsa - ikon cache temizligi...
    adb uninstall com.bahadirduzcan.controlapp >nul 2>nul
    adb uninstall com.bahadirduzcan.ytmusic >nul 2>nul
)
echo.
echo Telefona yukleniyor...
call flutter install --release
if errorlevel 1 (
    echo.
    echo [UYARI] Otomatik install basarisiz oldu.
    echo Manuel kurulum: asagidaki APK dosyasini telefona kopyalayin:
    echo   %CD%\build\app\outputs\flutter-apk\app-release.apk
) else (
    echo.
    echo Basariyla kuruldu!
)
goto :son

:no_install
echo.
echo APK dosyasi:
echo   %CD%\build\app\outputs\flutter-apk\app-release.apk
echo Telefona kendiniz kopyalayip kurabilirsiniz.
goto :son

:son
echo.
echo ===============================================================
echo   Bitti. Pencereyi kapatmak icin herhangi bir tusa basin.
echo ===============================================================
pause > nul
endlocal
