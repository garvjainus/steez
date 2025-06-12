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

async function getToken(): Promise<string> {
  // Check if we have a valid cached token (2 hours = 7200 seconds)
  if (token && Date.now() < tokenExpiry) {
    return token;
  }

  const appId = process.env.EBAY_APP_ID;
  const certId = process.env.EBAY_CERT_ID;
  const scope =
    process.env.EBAY_SCOPE || 'https://api.ebay.com/oauth/api_scope';

  if (!appId || !certId) {
    throw new Error('eBay credentials not configured');
  }

  const credentials = Buffer.from(`${appId}:${certId}`).toString('base64');

  const response: AxiosResponse<EbayTokenResponse> = await axios.post(
    'https://api.ebay.com/identity/v1/oauth2/token',
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
      'https://api.ebay.com/buy/browse/v1/item_summary/search',
      {
        params: {
          q: phrase,
          limit: 10,
          filter: [
            `attributeName:Size|attributeValue:${size}`,
            `deliveryCountry:${country}`,
            'buyingOptions:{FIXED_PRICE}',
          ].join(','),
        },
        headers: { Authorization: `Bearer ${token}` },
      },
    );
    return res.data.itemSummaries?.[0]?.itemWebUrl || null;
  } catch (error) {
    console.error(`eBay search error for "${phrase}":`, error);
    return null;
  }
}
