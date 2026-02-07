#!/bin/bash

echo "======================================"
echo "Obsidian Passkey Authentication Setup"
echo "======================================"
echo ""

# Check if running in automated mode (via environment variables)
if [ -n "$AUTH_DOMAIN" ] && [ -n "$AUTH_USERNAME" ] && [ -n "$AUTH_PASSWORD" ]; then
    echo "Running in automated mode..."
    DOMAIN=$AUTH_DOMAIN
    USERNAME=$AUTH_USERNAME
    DISPLAYNAME=${AUTH_DISPLAYNAME:-$AUTH_USERNAME}
    EMAIL=${AUTH_EMAIL:-$AUTH_USERNAME@$AUTH_DOMAIN}
    PASSWORD=$AUTH_PASSWORD
else
    # Interactive mode
    echo "Running in interactive mode..."
    echo ""
    
    # Get domain
    read -p "Enter your domain (e.g., yourdomain.com): " DOMAIN
    
    # Create user
    read -p "Enter username: " USERNAME
    read -p "Enter display name: " DISPLAYNAME
    read -p "Enter email: " EMAIL
    read -sp "Enter password: " PASSWORD
    echo ""
fi

# Generate random secrets
JWT_SECRET=$(openssl rand -hex 32)
SESSION_SECRET=$(openssl rand -hex 32)

# Update configuration.yml with secrets
sed -i "s/CHANGE_THIS_TO_A_RANDOM_STRING/$JWT_SECRET/" ./authelia/configuration.yml
sed -i "s/CHANGE_THIS_TO_ANOTHER_RANDOM_STRING/$SESSION_SECRET/" ./authelia/configuration.yml

echo "✓ Generated random secrets"
echo ""

# Update domain
sed -i "s/yourdomain.com/$DOMAIN/g" ./authelia/configuration.yml

echo "✓ Updated domain to $DOMAIN"
echo ""

# Generate password hash using Authelia container
echo "Generating password hash..."
HASH=$(docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$PASSWORD" | grep 'Digest:' | awk '{print $2}')

# Update users_database.yml
cat > ./authelia/users_database.yml << EOF
---
users:
  $USERNAME:
    displayname: "$DISPLAYNAME"
    password: "$HASH"
    email: $EMAIL
    groups:
      - admins
EOF

echo "✓ Created user $USERNAME"
echo ""
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Start containers:"
echo "   docker-compose up -d"
echo ""
echo "2. In Nginx Proxy Manager, create TWO Proxy Hosts:"
echo ""
echo "   A) Authelia Portal:"
echo "      Domain: auth.$DOMAIN"
echo "      Forward to: authelia:9091"
echo "      SSL: Enable with Let's Encrypt"
echo "      Websockets: ON"
echo ""
echo "   B) Obsidian (with Forward Auth):"
echo "      Domain: obsidian.$DOMAIN"
echo "      Forward to: obsidian:3000"
echo "      SSL: Enable with Let's Encrypt"
echo "      Websockets: ON"
echo "      Advanced tab, add this config:"
echo ""
cat << 'EOF'
      location / {
          # Forward auth to Authelia
          auth_request /authelia;
          auth_request_set $target_url $scheme://$http_host$request_uri;
          auth_request_set $user $upstream_http_remote_user;
          auth_request_set $groups $upstream_http_remote_groups;
          auth_request_set $name $upstream_http_remote_name;
          auth_request_set $email $upstream_http_remote_email;
          proxy_set_header Remote-User $user;
          proxy_set_header Remote-Groups $groups;
          proxy_set_header Remote-Name $name;
          proxy_set_header Remote-Email $email;

          error_page 401 =302 https://auth.YOURDOMAIN.COM/?rd=$target_url;

          proxy_pass http://obsidian:3000;
      }

      location /authelia {
          internal;
          proxy_pass http://authelia:9091/api/verify;
      }
EOF
echo ""
echo "      (Replace YOURDOMAIN.COM with $DOMAIN)"
echo ""
echo "3. Visit https://obsidian.$DOMAIN"
echo "   - Log in with your credentials"
echo "   - Register your passkey (Face ID/Touch ID/Windows Hello)"
echo "   - Next time you'll use just the passkey!"
echo ""
