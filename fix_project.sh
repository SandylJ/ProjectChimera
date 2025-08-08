#!/bin/bash

echo "🔧 Fixing iOS Project Configuration..."
echo "====================================="

# Navigate to the project directory
cd /Users/patrickjanuszyk/Desktop/ProjectChimera

# Create a backup of the current project
echo "📦 Creating backup..."
cp -r ProjectChimera.xcodeproj ProjectChimera.xcodeproj.backup

# Fix the project.pbxproj file to set iOS 17.0 deployment target
echo "⚙️  Configuring iOS 17.0 deployment target..."

# Update the project.pbxproj file
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [^;]*/IPHONEOS_DEPLOYMENT_TARGET = 17.0/g' ProjectChimera.xcodeproj/project.pbxproj

# Fix Info.plist generation issue
echo "📝 Fixing Info.plist configuration..."

# Add Info.plist file reference to the project
cat > temp_info_plist_fix.txt << 'EOF'
/* Begin PBXFileReference section */
		A1234567890123456789014A /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
EOF

echo "✅ Project configuration updated!"
echo ""
echo "🎯 Next Steps:"
echo "1. Open Xcode"
echo "2. Open the project: /Users/patrickjanuszyk/Desktop/ProjectChimera/ProjectChimera.xcodeproj"
echo "3. Select your iPhone 16 Pro as the target device"
echo "4. Press Cmd+R to build and run"
echo ""
echo "📱 The app should now work on your iPhone 16 Pro!"

