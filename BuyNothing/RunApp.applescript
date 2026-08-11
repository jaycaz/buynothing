-- AppleScript: Build and Run BuyNothing App
-- Uses command line tools to automate Xcode build/run
-- Run this on your Mac

-- Check if Xcode is installed
on run()
    try
        -- Get list of available devices
        set devicesText to (do shell script "xcrun simctl devices list")
        set deviceFound to false
        
        -- Find iPhone 16 Pro in the list
        if devicesText contains "iPhone 16 Pro" then
            set deviceFound to true
            set deviceName to "iPhone 16 Pro"
        else
            display dialog "No iPhone 16 Pro device found. Please make sure your device is booted in the simulator." buttons {{"OK"}} default button 1
            quit
        end if
        
        display notification "Found iPhone 16 Pro device"
        delay 2
        
        -- Build the app
        display notification "Building BuyNothing app..."
        do shell script "-project" "\"BuyNothing.xcodeproj\""
        do shell script "-scheme" "\"BuyNothing\""
        do shell script "-destination" "\"\" & deviceName & \"\"\""
        do shell script "-configuration" "\"Debug\""
        do shell script "build"
        delay 5
        
        if the result = "" then
            display notification "Build Succeeded! ✅" buttons {{"OK"}} default button 1
            delay 2
            
            -- Run the app
            display notification "Launching app..."
            do shell script "-project" "\"BuyNothing.xcodeproj\""
            do shell script "-scheme" "\"BuyNothing\""
            do shell script "-destination" "\"\" & deviceName & \"\"\""
            do shell script "-configuration" "\"Debug\""
            do shell script "run"
            delay 10
        else
            display notification "Build Failed! ❌" buttons {{"OK"}} default button 1
        end if
        
    exception error
        display notification "Error: " & error's message buttons {{"OK"}} default button 1
        error
    end try
end run

run()
delay 2

-- Done
display notification "Build process complete. Check your device!"
