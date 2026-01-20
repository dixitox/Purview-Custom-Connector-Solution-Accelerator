#!/usr/bin/env python3
"""
TAG DB XML to JSON Converter

Converts TAG DB XML exports to JSON format for processing by the Purview_TAG_DB_Scan notebook.

Usage:
    python examples/tag_db/convert_xml_to_json.py

Requirements:
    pip install xmltodict

The script reads the sample XML file and outputs a JSON file in the same directory.
For production use, consider using the Fabric pipeline instead:
    examples/tag_db/fabric/pipeline/Converte TAG DB XML Metadata to Json.json
"""
import json
import xmltodict

# Read the XML file
with open('examples/tag_db/example_data/tag-db-xml-sample.xml', 'r', encoding='utf-8') as xml_file:
    xml_content = xml_file.read()

# Convert XML to dictionary
data_dict = xmltodict.parse(xml_content)

# Convert to JSON
json_output = json.dumps(data_dict, indent=2)

# Save to file
with open('examples/tag_db/example_data/tag-db-xml-sample.json', 'w', encoding='utf-8') as json_file:
    json_file.write(json_output)

print("✅ Conversion complete!")
print("Output: example_data/tag-db-xml-sample.json")
