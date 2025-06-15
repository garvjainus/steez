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

export interface MatchResult {
  phrase: string;
  title: string;
  link: string;
  price?: string;
  imageUrl?: string;
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
  maxResults = 5,
): Promise<MatchResult[]> {
  if (!token || Date.now() >= tokenExpiry) {
    token = await getToken();
  }

  try {
    const root = getEbayRoot();

    // helper to execute search with optional sizeFilter
    const doSearch = async (includeSize: boolean): Promise<EbaySearchResponse> => {
      const filterParts = [
        includeSize && size ? `attributeName:Size|attributeValue:${size}` : undefined,
        `deliveryCountry:${country}`,
        'buyingOptions:{FIXED_PRICE}',
      ].filter(Boolean).join(',');

      const res: AxiosResponse<EbaySearchResponse> = await axios.get(
        `${root}/buy/browse/v1/item_summary/search`,
        {
          params: {
            q: phrase,
            limit: 20,
            filter: filterParts,
          },
          headers: { Authorization: `Bearer ${token}` },
        },
      );
      return res.data;
    };

    // First attempt with size filter
    let data = await doSearch(true);
    if (!data.itemSummaries || data.itemSummaries.length === 0) {
      // Fallback: try without size filter
      data = await doSearch(false);
    }

    const results: MatchResult[] = (data.itemSummaries || [])
      .slice(0, maxResults)
      .map((item) => ({
        phrase,
        title: item.title,
        link: item.itemWebUrl,
        price: item.price ? `${item.price.value} ${item.price.currency}` : undefined,
        imageUrl: item.image?.imageUrl,
      }));

    return results;
  } catch (error) {
    console.error(`eBay search error for "${phrase}":`, error);
    return [];
  }
}
