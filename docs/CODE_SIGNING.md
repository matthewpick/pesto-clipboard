# Code Signing and Notarization Setup

This document describes how to set up code signing and notarization for Pesto Clipboard releases once an Apple Developer account is available.

## Prerequisites

- Apple Developer Program membership ($99/year)
- Access to the GitHub repository settings

## Step 1: Create Developer ID Certificate

1. Open **Keychain Access** on your Mac
2. Go to **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority**
3. Enter your email and select "Saved to disk"
4. Go to https://developer.apple.com/account/resources/certificates/list
5. Click the **+** button to create a new certificate
6. Select **Developer ID Application** (for distributing outside the App Store)
7. Upload the certificate request file you created
8. Download the certificate and double-click to install it in Keychain Access

## Step 2: Export Certificate as .p12

1. Open **Keychain Access**
2. Find your **Developer ID Application** certificate (under "My Certificates")
3. Right-click → **Export**
4. Save as `.p12` format
5. Set a strong password (you'll need this later)

## Step 3: Get Your Team ID

1. Go to https://developer.apple.com/account
2. Click **Membership Details** in the sidebar
3. Copy your **Team ID** (10-character string)

## Step 4: Create App-Specific Password

Apple requires an app-specific password for notarization (not your regular Apple ID password).

1. Go to https://appleid.apple.com/account/manage
2. Sign in with your Apple ID
3. Go to **Sign-In and Security → App-Specific Passwords**
4. Click **Generate an app-specific password**
5. Name it something like "GitHub Actions Notarization"
6. Copy the generated password

## Step 5: Add GitHub Secrets

Go to your repository: **Settings → Secrets and variables → Actions → New repository secret**

Add these secrets:

| Secret Name | How to Get the Value |
|-------------|---------------------|
| `APPLE_CERTIFICATE_BASE64` | Run: `base64 -i your-certificate.p12 \| pbcopy` then paste |
| `APPLE_CERTIFICATE_PASSWORD` | The password you set when exporting the .p12 |
| `APPLE_ID` | Your Apple ID email address |
| `APPLE_ID_PASSWORD` | The app-specific password from Step 4 |
| `APPLE_TEAM_ID` | Your Team ID from Step 3 |

## Step 6: Update Release Workflow

Replace the contents of `.github/workflows/release.yml` with the following:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write
  attestations: write
  id-token: write

jobs:
  build-and-release:
    name: Build and Release
    runs-on: macos-15

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select latest Xcode
        run: |
          LATEST_XCODE=$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1)
          echo "Using Xcode: $LATEST_XCODE"
          sudo xcode-select -s "$LATEST_XCODE/Contents/Developer"

      - name: Show Xcode version
        run: |
          xcodebuild -version
          swift --version

      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Install Apple certificate
        env:
          APPLE_CERTIFICATE_BASE64: ${{ secrets.APPLE_CERTIFICATE_BASE64 }}
          APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
        run: |
          # Create temporary keychain
          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
          KEYCHAIN_PASSWORD=$(openssl rand -base64 32)

          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

          # Import certificate
          CERTIFICATE_PATH=$RUNNER_TEMP/certificate.p12
          echo -n "$APPLE_CERTIFICATE_BASE64" | base64 --decode -o "$CERTIFICATE_PATH"

          security import "$CERTIFICATE_PATH" \
            -P "$APPLE_CERTIFICATE_PASSWORD" \
            -A \
            -t cert \
            -f pkcs12 \
            -k "$KEYCHAIN_PATH"

          security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security list-keychain -d user -s "$KEYCHAIN_PATH"

          echo "KEYCHAIN_PATH=$KEYCHAIN_PATH" >> $GITHUB_ENV

      - name: Resolve Swift Package Dependencies
        run: |
          xcodebuild -resolvePackageDependencies \
            -project PestoClipboard/PestoClipboard.xcodeproj \
            -scheme PestoClipboard

      - name: Build and Sign Release
        env:
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          xcodebuild build \
            -project PestoClipboard/PestoClipboard.xcodeproj \
            -scheme PestoClipboard \
            -configuration Release \
            -derivedDataPath build \
            -arch arm64 \
            -arch x86_64 \
            CODE_SIGN_STYLE=Manual \
            CODE_SIGN_IDENTITY="Developer ID Application" \
            DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
            OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH"

      - name: Notarize app
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          APP_PATH="build/Build/Products/Release/Pesto Clipboard.app"

          # Create a ZIP for notarization
          ditto -c -k --keepParent "$APP_PATH" "PestoClipboard.zip"

          # Submit for notarization
          xcrun notarytool submit "PestoClipboard.zip" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_ID_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait

          # Staple the notarization ticket
          xcrun stapler staple "$APP_PATH"

      - name: Install create-dmg
        run: brew install create-dmg

      - name: Create DMG
        run: |
          APP_PATH="build/Build/Products/Release/Pesto Clipboard.app"
          DMG_NAME="PestoClipboard-${{ steps.version.outputs.VERSION }}.dmg"

          mkdir -p dmg-contents
          cp -R "$APP_PATH" dmg-contents/

          create-dmg \
            --volname "Pesto Clipboard" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "Pesto Clipboard.app" 150 185 \
            --hide-extension "Pesto Clipboard.app" \
            --app-drop-link 450 185 \
            "$DMG_NAME" \
            dmg-contents/ \
            || true

          if [ ! -f "$DMG_NAME" ]; then
            hdiutil create -volname "Pesto Clipboard" -srcfolder dmg-contents -ov -format UDZO "$DMG_NAME"
          fi

          # Sign the DMG
          codesign --sign "Developer ID Application" "$DMG_NAME"

          # Notarize the DMG
          xcrun notarytool submit "$DMG_NAME" \
            --apple-id "${{ secrets.APPLE_ID }}" \
            --password "${{ secrets.APPLE_ID_PASSWORD }}" \
            --team-id "${{ secrets.APPLE_TEAM_ID }}" \
            --wait

          xcrun stapler staple "$DMG_NAME"

          echo "DMG_NAME=$DMG_NAME" >> $GITHUB_ENV

      - name: Calculate SHA256
        id: sha256
        run: |
          SHA256=$(shasum -a 256 "$DMG_NAME" | awk '{print $1}')
          echo "SHA256=$SHA256" >> $GITHUB_OUTPUT
          echo "SHA256: $SHA256"

      - name: Generate artifact attestation
        uses: actions/attest-build-provenance@v2
        with:
          subject-path: ${{ env.DMG_NAME }}

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          name: Pesto Clipboard v${{ steps.version.outputs.VERSION }}
          draft: false
          prerelease: ${{ contains(github.ref, '-beta') || contains(github.ref, '-alpha') || contains(github.ref, '-rc') }}
          generate_release_notes: true
          files: ${{ env.DMG_NAME }}
          body: |
            ## Installation

            ### Manual Download
            1. Download `${{ env.DMG_NAME }}` below
            2. Open the DMG and drag Pesto Clipboard to Applications
            3. Launch the app from Applications

            ## Verification

            SHA256: `${{ steps.sha256.outputs.SHA256 }}`

            Verify with:
            ```bash
            echo "${{ steps.sha256.outputs.SHA256 }}  ${{ env.DMG_NAME }}" | shasum -a 256 -c
            ```
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Cleanup keychain
        if: always()
        run: |
          if [ -f "$KEYCHAIN_PATH" ]; then
            security delete-keychain "$KEYCHAIN_PATH"
          fi
```

## Verification

After setting up, create a test release to verify everything works:

```bash
git tag v0.0.2-test
git push origin v0.0.2-test
```

Check the GitHub Actions logs for any errors. If successful:
- The app should be signed with your Developer ID
- The app should be notarized by Apple
- Users can install without any Gatekeeper warnings

## Troubleshooting

### "The specified item could not be found in the keychain"
- Ensure the certificate is a **Developer ID Application** certificate (not Mac App Distribution)
- Verify the base64 encoding was done correctly

### Notarization fails with "Invalid credentials"
- Verify you're using an app-specific password, not your Apple ID password
- Check that the Team ID matches the certificate's team

### "Code signature invalid"
- Ensure all nested frameworks and binaries are also signed
- Check that the bundle identifier matches what's registered in your Developer account

## Security Notes

- Never commit certificates or passwords to the repository
- Rotate app-specific passwords periodically
- The GitHub Actions keychain is temporary and deleted after each run
