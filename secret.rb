require "jwt"

# Get the key file path and key ID from environment variables
key_file = ENV['APPLE_AUTH_KEY_FILE']
key_id = ENV['APPLE_AUTH_KEY_ID']

# Check that the environment variables are set
unless key_file && key_id
  puts "Error: Please set the APPLE_AUTH_KEY_FILE and APPLE_AUTH_KEY_ID environment variables."
  exit 1
end

# Check that the key file exists
unless File.exist?(key_file)
  puts "Error: The key file was not found at #{key_file}"
  exit 1
end

private_key = OpenSSL::PKey::EC.new IO.read key_file

token = JWT.encode(
	{
		iss: "YOUR_TEAM_ID", # Your Apple Developer Team ID
		iat: Time.now.to_i,
		exp: Time.now.to_i + 86400*180, # 180 days
		aud: "https://appleid.apple.com",
		sub: "com.steez.app" # Your app's bundle ID
	},
	private_key,
	"ES256",
	header_fields=
	{
		kid: key_id
	}
)

puts token