#!/usr/bin/env python3
"""
Quick API Key Fix Script
Helps resolve API key issues step by step
"""

import os
import re


def check_current_key():
    """Display current key info"""
    print("🔍 CURRENT API KEY INFO")
    print("=" * 30)
    
    try:
        with open('.env', 'r') as f:
            content = f.read()
        
        for line in content.split('\n'):
            if line.startswith('GEMINI_API_KEY='):
                key = line.split('=', 1)[1].strip().strip('"\'')
                print(f"Key: {key[:15]}...{key[-8:]}")
                print(f"Length: {len(key)} chars")
                print(f"Format: {'✅ Valid' if key.startswith('AIza') and len(key) > 35 else '❌ Invalid'}")
                return key
        
        print("❌ No GEMINI_API_KEY found")
        return None
        
    except FileNotFoundError:
        print("❌ .env file not found")
        return None


def create_new_env_template():
    """Create a new .env with proper format"""
    print("\n📝 CREATING NEW .env TEMPLATE")
    print("=" * 30)
    
    # Backup existing .env
    if os.path.exists('.env'):
        os.rename('.env', '.env.backup')
        print("✅ Backed up existing .env to .env.backup")
    
    # Create new template
    template = """# Tessera API Keys
# Get your Gemini API key from: https://aistudio.google.com/app/apikey
GEMINI_API_KEY=your_gemini_api_key_here

# Optional: Anthropic API key for Claude (if needed)
ANTHROPIC_API_KEY=your_anthropic_key_here

# Gemini Service Configuration
GEMINI_MODEL=gemini-1.5-flash
GEMINI_TEMPERATURE=0.7
GEMINI_MAX_TOKENS=2048
"""
    
    with open('.env', 'w') as f:
        f.write(template)
    
    print("✅ Created new .env template")
    print("📝 Please edit .env and add your actual API key")


def validate_key_format(key):
    """Validate API key format"""
    if not key:
        return False, "No key provided"
    
    if not key.startswith('AIza'):
        return False, "Should start with 'AIza'"
    
    if len(key) < 35:
        return False, f"Too short ({len(key)} chars)"
    
    if len(key) > 50:
        return False, f"Too long ({len(key)} chars)"
    
    # Check for invalid characters
    if not re.match(r'^[A-Za-z0-9_-]+$', key):
        return False, "Contains invalid characters"
    
    return True, "Format is valid"


def interactive_key_entry():
    """Interactive API key entry with validation"""
    print("\n🔑 INTERACTIVE API KEY ENTRY")
    print("=" * 30)
    print("Please paste your Gemini API key:")
    print("(Get one from: https://aistudio.google.com/app/apikey)")
    print()
    
    while True:
        key = input("API Key: ").strip()
        
        if not key:
            print("❌ No key entered. Try again or Ctrl+C to exit.")
            continue
        
        # Remove any quotes or extra characters
        key = key.strip('"\'')
        
        # Validate format
        is_valid, message = validate_key_format(key)
        
        if is_valid:
            print(f"✅ {message}")
            
            # Update .env file
            try:
                # Read existing .env
                env_content = ""
                if os.path.exists('.env'):
                    with open('.env', 'r') as f:
                        env_content = f.read()
                
                # Update or add GEMINI_API_KEY
                lines = env_content.split('\n')
                updated = False
                
                for i, line in enumerate(lines):
                    if line.startswith('GEMINI_API_KEY='):
                        lines[i] = f"GEMINI_API_KEY={key}"
                        updated = True
                        break
                
                if not updated:
                    lines.append(f"GEMINI_API_KEY={key}")
                
                # Write back
                with open('.env', 'w') as f:
                    f.write('\n'.join(lines))
                
                print("✅ Updated .env file")
                return key
                
            except Exception as e:
                print(f"❌ Failed to update .env: {e}")
                return None
        else:
            print(f"❌ {message}")
            print("Please try again with a valid API key.")


def main():
    """Main fix routine"""
    print("🔧 GEMINI API KEY FIX TOOL")
    print("=" * 40)
    
    current_key = check_current_key()
    
    if current_key and current_key != "your_gemini_api_key_here":
        print("\n⚠️  Current key is rejected by Google API")
        print("This usually means:")
        print("  1. Key was revoked/expired")
        print("  2. Key has API restrictions")
        print("  3. Billing/quota issues")
        print()
        
        choice = input("Enter new API key? (y/n): ").lower().strip()
        if choice == 'y':
            new_key = interactive_key_entry()
            if new_key:
                print("\n✅ API key updated!")
                print("🔄 Now restart your services:")
                print("   1. Stop backend (Ctrl+C)")
                print("   2. Run: npm run backend")
                print("   3. Test: python3 validate_api_key.py")
        else:
            print("💡 To fix the current key:")
            print("   1. Check https://console.cloud.google.com/apis/credentials")
            print("   2. Verify key restrictions and quotas")
            print("   3. Regenerate key if needed")
    else:
        print("\n📝 No valid API key found")
        create_new_env_template()
        new_key = interactive_key_entry()
        if new_key:
            print("\n✅ API key configured!")
            print("🔄 Now restart your services and test")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n🛑 Cancelled by user")
    except Exception as e:
        print(f"\n💥 Error: {e}")
