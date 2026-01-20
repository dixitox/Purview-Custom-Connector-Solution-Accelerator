#!/usr/bin/env python3
"""
Quick script to convert TAG DB XML to JSON format for testing
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
