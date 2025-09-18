#!/bin/sh

RESOURCES_PATH="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
SERVICES_PLIST="$RESOURCES_PATH/services.plist"

# Retrieve the list of services
REGULAR_SERVICES=$(find "$SRCROOT/stts/Services" -name "*.swift" -not -path "*Super*" -not -path "*Generated*" | awk -F/ '{ print $NF }' | sed s/.swift//g | sort | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g')
GENERATED_SERVICES=$(find "$SRCROOT/stts/Services/Generated" -name "*.swift" -print0 | xargs -0 cat | grep "class " | sed s/'final class '//g | sed s/'class '//g | sed 's/:.*//' | tr '\n' ' ')
SERVICES="$REGULAR_SERVICES $GENERATED_SERVICES"

# Create the services plist file
echo "{}" > "$SERVICES_PLIST"

# Write the list of services into the plist file as an array
defaults write "$SERVICES_PLIST" "services" -array $SERVICES

# Remove all quarantine attributes as they block submissions to App Store
xattr -c "$SERVICES_PLIST"
