import pytest
import polars as pl
from polars.testing import assert_frame_equal
from silver_to_gold import transform_df

def test_transform_df():
    schema_polars = {
        "text": pl.String(),
        "meta": pl.Struct({"pile_set_name": pl.String()})
    }

    data = [
        {"text": "i will talk about the bad salaries in France ! These crazy spookies tax you like never URSS did ! And you would agree to this ?", "meta": {"pile_set_name": "Pile-CC"}},
        {"text": "Stone Cold Steve Austin", "meta": {"pile_set_name": "Pile-CC"}},
        {"text": "The first thing I want to be done, is to get that piece of crap out of my ring. Don't just get him out of the ring, get him out of the WWF because I've proved son, without a shadow of a doubt, you ain't got what it takes anymore! You sit there and you thump your Bible, and you say your prayers, and it didn t get you anywhere. Talk about your psalms, talk about John 3:16… Austin 3:16 says I just whoopped your ass! copyright WWE", "meta": {"pile_set_name": "Pile-CC"}}
    ]
    
    df = pl.DataFrame(data, schema=schema_polars)

    result = transform_df(df)

    expected_data = [
        {
            "text": "i will talk about the bad salaries in France ! These crazy spookies tax you like never URSS did ! And you would agree to this ?", 
            "set_name": "Pile-CC"
        }
    ]
    expected_df = pl.DataFrame(expected_data)
    
    assert_frame_equal(result, expected_df)