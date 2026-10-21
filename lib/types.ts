export type Media = {
  id: string;
  user_id: string;
  media_type: string;
  purpose: string;
  created_at: string;
  model: string | null;
  prompt: string;
  image_path: string | null;
  meme_template: {
    imageUrl?: string;
    storagePath?: string;
    id?: string;
  } | null;
  caption_choices: string[] | null;
  selected_caption: number | null;
  generated_body: string;
  post_id: string | null;
  title: string;
  body: string;
  location: string;
  votes: number;
  comments: number;
  preview?: string | null;
};
export type Profile = {
  id: string;
  first_name: string | null;
  last_name: string | null;
  created_at: string;
  is_superadmin: boolean;
  generations: number;
  votes: number;
};
export type Vote = {
  id: string;
  user_id: string;
  value: number;
  created_at: string;
  rant_id: string;
  title: string;
  voter: string;
};
export type Overview = {
  users: number;
  generations: number;
  published: number;
  votes: number;
  upvotes: number;
  downvotes: number;
  images: number;
  captions: number;
  activity: { day: string; generations: number; votes: number }[];
  leaders: {
    id: string;
    title: string;
    votes: number;
    upvotes: number;
    downvotes: number;
  }[];
  divisive: {
    id: string;
    title: string;
    votes: number;
    disagreement: number;
  }[];
};
