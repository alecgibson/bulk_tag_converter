# Bulk Tag Converter Tool

This tool is designed to convert taxon tagging spreadsheets to a format
accepted by [Content Tagger](https://github.com/alphagov/content-tagger).

## Preparing the spreadsheet

The tool reads spreadsheets from the internet, like Google Sheets. Prepare
a Google sheet for conversion by going to File > Publish to the web...  
Then choose the sheet to publish and publish it as Tab-separated values (.tsv)

## Using the tool

Make sure the tool is executable by running `chmod +x bulk_tag_converter.rb`

Execute the script with
`./bulk_tag_converter.rb 'https://docs.google.com/my-tsv-spreadsheet'
'output.csv'`

The first argument should be the URL to the TSV published spreadsheet, and
the second argument should be the path to the output CSV file.
