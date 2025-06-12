import axios, { AxiosResponse } from 'axios';

let token: string | null = null;
let tokenExpiry: number = 0;

interface EbayTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

interface EbayItemSummary {
  itemId: string;
  title: string;
  price?: {
    value: string;
    currency: string;
  };
  itemWebUrl: string;
  image?: {
    imageUrl: string;
  };
}

interface EbaySearchResponse {
  itemSummaries?: EbayItemSummary[];
  total: number;
  limit: number;
  offset: number;
}

function getEbayRoot(): string {
  return process.env.EBAY_ENV === 'SANDBOX'
    ? 'https://api.sandbox.ebay.com'
    : 'https://api.ebay.com';
}

async function getToken(): Promise<string> {
  // Check if we have a valid cached token (2 hours = 7200 seconds)
  if (token && Date.now() < tokenExpiry) {
    return token;
  }

  const appId = process.env.EBAY_APP_ID;
  const certId = process.env.EBAY_CERT_ID;
  const scope =
    process.env.EBAY_SCOPE || 'https://api.ebay.com/oauth/api_scope';

  console.log('🔍 eBay Debug:');
  console.log('  APP_ID:', appId);
  console.log('  CERT_ID:', certId);
  const ebayRoot = getEbayRoot();
  console.log('  Target URL:', `${ebayRoot}/identity/v1/oauth2/token`);
  console.log('  EBAY_ENV:', process.env.EBAY_ENV);

  if (!appId || !certId) {
    throw new Error('eBay credentials not configured');
  }

  const credentials = Buffer.from(`${appId}:${certId}`).toString('base64');

  const response: AxiosResponse<EbayTokenResponse> = await axios.post(
    `${ebayRoot}/identity/v1/oauth2/token`,
    'grant_type=client_credentials&scope=' + encodeURIComponent(scope),
    {
      headers: {  
        Authorization: `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    },
  );

  token = response.data.access_token;
  // Cache for 2 hours (7200 seconds)
  tokenExpiry = Date.now() + 7200 * 1000;
  return token;
}

export async function searchEbay(
  phrase: string,
  size: string,
  country: string,
): Promise<string | null> {
  if (!token || Date.now() >= tokenExpiry) {
    token = await getToken();
  }

  try {
    const res: AxiosResponse<EbaySearchResponse> = await axios.get(
      `${getEbayRoot()}/buy/browse/v1/item_summary/search`,
      {
        params: {
          q: phrase,
          limit: 10,
          filter: [
            // Optional size filter – remove if size is empty
            size ? `attributeName:Size|attributeValue:${size}` : undefined,
            // Ensure items ship to the specified country
            `deliveryCountry:${country}`,
            // Only fixed-price listings (no auctions)
            'buyingOptions:{FIXED_PRICE}',
          ]
            // Remove undefined entries if size was blank
            .filter(Boolean)
            .join(','),
        },
        headers: { Authorization: `Bearer ${token}` },
      },
    );

    // Return the first item's web URL if present, otherwise null
    return res.data.itemSummaries?.[0]?.itemWebUrl || null;
  } catch (error) {
    console.error(`eBay search error for "${phrase}":`, error);
    return null;
  }
}
