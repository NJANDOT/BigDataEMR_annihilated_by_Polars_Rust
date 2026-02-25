
pub struct Config {
    pub aws_region: &'static str,
    pub ssm_username_param: &'static str,
    pub ssm_key_param: &'static str,
    pub kaggle_dataset_url: &'static str,
    pub target_filename: &'static str,
    pub s3_bucket: &'static str,
    pub s3_key: &'static str,
}

impl Config {
    pub fn default() -> Self {
        Self {
            aws_region: "eu-west-3",
            ssm_username_param: "/kaggle/username",
            ssm_key_param: "/kaggle/key",
            kaggle_dataset_url:
                "https://www.kaggle.com/datasets/dschettler8845/the-pile-dataset-part-00-of-29",
            target_filename: "00.jsonl",
            s3_bucket: "sparkresultsjjjmain",
            s3_key: "the-pile/bronze/00.jsonl",
        }
    }
}
