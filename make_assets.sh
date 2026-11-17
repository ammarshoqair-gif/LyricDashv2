#!/bin/bash
# Runs automatically during the cloud build.
# Turns the flat AppIcon.png file into the icon folder that Xcode expects.
set -e

if [ ! -f AppIcon.png ]; then
  echo "No AppIcon.png found, building without an icon."
  exit 0
fi

mkdir -p Assets.xcassets/AppIcon.appiconset
cp AppIcon.png Assets.xcassets/AppIcon.appiconset/AppIcon.png

cat > Assets.xcassets/Contents.json <<'JSON'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

cat > Assets.xcassets/AppIcon.appiconset/Contents.json <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "App icon ready."
