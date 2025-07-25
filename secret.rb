require "jwt"

key_file = "/Users/garvjain/Downloads/AuthKey_A84UV662NP.p8"
team_id = "PF4MU983T9"
client_id = "com.steez.supabase"
key_id = "A84UV662NP"
validity_period = 180 # In days. Max 180 (6 months) according to Apple docs.

private_key = OpenSSL::PKey::EC.new IO.read key_file

token = JWT.encode(
	{
		iss: team_id,
		iat: Time.now.to_i,
		exp: Time.now.to_i + 86400 * validity_period,
		aud: "https://appleid.apple.com",
		sub: client_id
	},
	private_key,
	"ES256",
	header_fields=
	{
		kid: key_id 
	}
)
puts token