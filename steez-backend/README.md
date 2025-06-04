# Steez Backend

This is the backend server for the Steez app, which handles image processing, clothing detection, and product matching.

## Features

- Image processing with Google Cloud Vision API
- Clothing detection and categorization
- Product matching and price comparison
- Wardrobe management API
- Asynchronous job processing

## Tech Stack

- **Language**: Node.js / TypeScript
- **Framework**: NestJS
- **APIs**: Google Cloud Vision API
- **Image Processing**: Sharp
- **File Handling**: Multer

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- Google Cloud Vision API key or credentials

### Installation

1. Clone the repository:
```
git clone https://github.com/yourusername/steez.git
cd steez/steez-backend
```

2. Install dependencies:
```
npm install
```

3. Set up environment variables:
```
cp .env.example .env
```
Edit the `.env` file to add your Google Cloud Vision API key.

### Running the App

```
# Development mode
npm run start:dev

# Production build
npm run build
npm run start:prod
```

## API Endpoints

### Image Processing

- `POST /image-processing/upload` - Upload and process an image file
- `POST /image-processing/process-base64` - Process a base64-encoded image
- `GET /image-processing/job-status/:jobId` - Get the status of a processing job

### Product Matching

- `GET /product-match/search` - Search for products based on name, category, color, etc.
- `POST /product-match/refresh-prices` - Refresh prices for provided product links

### Wardrobe

- `GET /wardrobe/:userId` - Get all wardrobe items for a user
- `GET /wardrobe/:userId/item/:itemId` - Get a specific wardrobe item
- `POST /wardrobe/:userId` - Add a new wardrobe item
- `POST /wardrobe/:userId/bulk` - Add multiple wardrobe items
- `PATCH /wardrobe/:userId/item/:itemId` - Update a wardrobe item
- `DELETE /wardrobe/:userId/item/:itemId` - Delete a wardrobe item

## Development

### Project Structure

```
steez-backend/
├── src/
│   ├── image-processing/    # Image processing module
│   ├── product-match/       # Product matching module
│   ├── wardrobe/            # Wardrobe management module
│   ├── models/              # Data models
│   ├── app.module.ts        # Main application module
│   └── main.ts              # Application entry point
├── uploads/                 # Temporary storage for uploaded files
└── .env                    # Environment variables
```

### Testing

```
# Unit tests
npm run test

# End-to-end tests
npm run test:e2e
```

## Integration with iOS App

The iOS app uses these API endpoints to:

1. Submit images for processing
2. Check job status for processing results
3. Add detected clothing items to the user's wardrobe
4. Fetch and display wardrobe items
5. Refresh product prices

## License

This project is licensed under the MIT License - see the LICENSE file for details.
