-- Migration: Create wardrobe tables for user account-based storage
-- This replaces the local Realm storage with cloud-based user-specific wardrobe data

-- Create wardrobe_items table
CREATE TABLE wardrobe_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  image_url TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create wardrobe_clothing_pieces table
CREATE TABLE wardrobe_clothing_pieces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wardrobe_item_id UUID NOT NULL REFERENCES wardrobe_items(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL,
  phrase TEXT NOT NULL,
  confidence DOUBLE PRECISION NOT NULL,
  category TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create wardrobe_ebay_matches table
CREATE TABLE wardrobe_ebay_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clothing_piece_id UUID NOT NULL REFERENCES wardrobe_clothing_pieces(id) ON DELETE CASCADE,
  phrase TEXT NOT NULL,
  link TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_wardrobe_items_user_id ON wardrobe_items(user_id);
CREATE INDEX idx_wardrobe_items_created_at ON wardrobe_items(created_at DESC);
CREATE INDEX idx_wardrobe_items_user_created ON wardrobe_items(user_id, created_at DESC);

CREATE INDEX idx_clothing_pieces_wardrobe_item ON wardrobe_clothing_pieces(wardrobe_item_id);
CREATE INDEX idx_clothing_pieces_category ON wardrobe_clothing_pieces(category);

CREATE INDEX idx_ebay_matches_clothing_piece ON wardrobe_ebay_matches(clothing_piece_id);

-- Create trigger to automatically update updated_at on wardrobe_items
CREATE TRIGGER update_wardrobe_items_updated_at 
  BEFORE UPDATE ON wardrobe_items 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE wardrobe_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE wardrobe_clothing_pieces ENABLE ROW LEVEL SECURITY;
ALTER TABLE wardrobe_ebay_matches ENABLE ROW LEVEL SECURITY;

-- RLS Policies for wardrobe_items
CREATE POLICY "Users can view their own wardrobe items" ON wardrobe_items
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own wardrobe items" ON wardrobe_items
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own wardrobe items" ON wardrobe_items
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own wardrobe items" ON wardrobe_items
  FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for wardrobe_clothing_pieces
CREATE POLICY "Users can view clothing pieces of their wardrobe items" ON wardrobe_clothing_pieces
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM wardrobe_items 
      WHERE wardrobe_items.id = wardrobe_clothing_pieces.wardrobe_item_id 
      AND wardrobe_items.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert clothing pieces for their wardrobe items" ON wardrobe_clothing_pieces
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM wardrobe_items 
      WHERE wardrobe_items.id = wardrobe_clothing_pieces.wardrobe_item_id 
      AND wardrobe_items.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update clothing pieces of their wardrobe items" ON wardrobe_clothing_pieces
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM wardrobe_items 
      WHERE wardrobe_items.id = wardrobe_clothing_pieces.wardrobe_item_id 
      AND wardrobe_items.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete clothing pieces of their wardrobe items" ON wardrobe_clothing_pieces
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM wardrobe_items 
      WHERE wardrobe_items.id = wardrobe_clothing_pieces.wardrobe_item_id 
      AND wardrobe_items.user_id = auth.uid()
    )
  );

-- RLS Policies for wardrobe_ebay_matches
CREATE POLICY "Users can view ebay matches of their clothing pieces" ON wardrobe_ebay_matches
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM wardrobe_clothing_pieces cp
      JOIN wardrobe_items wi ON wi.id = cp.wardrobe_item_id
      WHERE cp.id = wardrobe_ebay_matches.clothing_piece_id 
      AND wi.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert ebay matches for their clothing pieces" ON wardrobe_ebay_matches
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM wardrobe_clothing_pieces cp
      JOIN wardrobe_items wi ON wi.id = cp.wardrobe_item_id
      WHERE cp.id = wardrobe_ebay_matches.clothing_piece_id 
      AND wi.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update ebay matches of their clothing pieces" ON wardrobe_ebay_matches
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM wardrobe_clothing_pieces cp
      JOIN wardrobe_items wi ON wi.id = cp.wardrobe_item_id
      WHERE cp.id = wardrobe_ebay_matches.clothing_piece_id 
      AND wi.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete ebay matches of their clothing pieces" ON wardrobe_ebay_matches
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM wardrobe_clothing_pieces cp
      JOIN wardrobe_items wi ON wi.id = cp.wardrobe_item_id
      WHERE cp.id = wardrobe_ebay_matches.clothing_piece_id 
      AND wi.user_id = auth.uid()
    )
  );

-- Add comments for documentation
COMMENT ON TABLE wardrobe_items IS 'User wardrobe items with associated image and metadata';
COMMENT ON TABLE wardrobe_clothing_pieces IS 'Individual clothing pieces identified within wardrobe items';
COMMENT ON TABLE wardrobe_ebay_matches IS 'eBay shopping matches for clothing pieces';

COMMENT ON COLUMN wardrobe_items.user_id IS 'ID of the user who owns this wardrobe item';
COMMENT ON COLUMN wardrobe_items.image_url IS 'URL of the source image for this wardrobe item';

COMMENT ON COLUMN wardrobe_clothing_pieces.wardrobe_item_id IS 'Reference to the parent wardrobe item';
COMMENT ON COLUMN wardrobe_clothing_pieces.item_type IS 'Type of clothing item (e.g., shirt, pants, etc.)';
COMMENT ON COLUMN wardrobe_clothing_pieces.phrase IS 'Descriptive phrase for the clothing piece';
COMMENT ON COLUMN wardrobe_clothing_pieces.confidence IS 'AI confidence score for the identification (0.0-1.0)';
COMMENT ON COLUMN wardrobe_clothing_pieces.category IS 'Category of the clothing piece (top, bottom, outerwear, etc.)';

COMMENT ON COLUMN wardrobe_ebay_matches.clothing_piece_id IS 'Reference to the clothing piece this match belongs to';
COMMENT ON COLUMN wardrobe_ebay_matches.phrase IS 'Search phrase used to find this match';
COMMENT ON COLUMN wardrobe_ebay_matches.link IS 'URL link to the eBay listing';
