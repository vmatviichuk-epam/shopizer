#!/usr/bin/env python3
"""
Create dummy customers in Shopizer via the admin API.

Usage:
  1. Login to admin panel or get a token via:
     curl -s -X POST http://localhost:8080/api/v1/private/login \
       -H "Content-Type: application/json" \
       -d '{"username":"admin@shopizer.com","password":"password"}'

  2. Run this script with the token:
     python3 create-dummy-customers.py <BEARER_TOKEN>

  3. Or set the environment variable:
     export SHOPIZER_TOKEN="eyJhbG..."
     python3 create-dummy-customers.py
"""

import urllib.request
import json
import sys
import os

BASE_URL = os.environ.get("SHOPIZER_URL", "http://localhost:8080")
API_URL = f"{BASE_URL}/api/v1/private/customer"
STORE = os.environ.get("SHOPIZER_STORE", "DEFAULT")

TOKEN = (
    sys.argv[1] if len(sys.argv) > 1
    else os.environ.get("SHOPIZER_TOKEN")
)

if not TOKEN:
    print("Error: provide a Bearer token as argument or set SHOPIZER_TOKEN env var")
    print("Example: python3 create-dummy-customers.py eyJhbG...")
    sys.exit(1)

CUSTOMERS = [
    ("James", "Smith", "New York", "NY", "10001"),
    ("Mary", "Johnson", "Los Angeles", "CA", "90001"),
    ("Robert", "Williams", "Chicago", "IL", "60601"),
    ("Patricia", "Brown", "Houston", "TX", "77001"),
    ("Michael", "Jones", "Phoenix", "AZ", "85001"),
    ("Jennifer", "Garcia", "Philadelphia", "PA", "19101"),
    ("William", "Miller", "San Antonio", "TX", "78201"),
    ("Linda", "Davis", "San Diego", "CA", "92101"),
    ("David", "Rodriguez", "Dallas", "TX", "75201"),
    ("Elizabeth", "Martinez", "San Jose", "CA", "95101"),
    ("Richard", "Hernandez", "Austin", "TX", "73301"),
    ("Barbara", "Lopez", "Jacksonville", "FL", "32099"),
    ("Joseph", "Gonzalez", "Fort Worth", "TX", "76101"),
    ("Susan", "Wilson", "Columbus", "OH", "43085"),
    ("Thomas", "Anderson", "Charlotte", "NC", "28201"),
    ("Jessica", "Thomas", "Indianapolis", "IN", "46201"),
    ("Christopher", "Taylor", "San Francisco", "CA", "94101"),
    ("Sarah", "Moore", "Seattle", "WA", "98101"),
    ("Charles", "Jackson", "Denver", "CO", "80201"),
    ("Karen", "Martin", "Nashville", "TN", "37201"),
    ("Daniel", "Lee", "Baltimore", "MD", "21201"),
    ("Lisa", "Perez", "Louisville", "KY", "40201"),
    ("Matthew", "Thompson", "Portland", "OR", "97201"),
    ("Nancy", "White", "Milwaukee", "WI", "53201"),
    ("Anthony", "Harris", "Atlanta", "GA", "30301"),
]

PASSWORD = "Password123"

created = 0
failed = 0

for i, (first, last, city, state, zip_code) in enumerate(CUSTOMERS, 1):
    email = f"{first.lower()}.{last.lower()}@testshop.com"
    payload = {
        "billing": {
            "company": "",
            "address": f"{100 + i * 10} Main St",
            "city": city,
            "postalCode": zip_code,
            "stateProvince": state,
            "country": "US",
            "zone": state,
            "firstName": first,
            "lastName": last,
            "phone": f"+1-555-{i:03d}-{1000 + i:04d}"
        },
        "delivery": {
            "company": "", "address": "", "city": "", "postalCode": "",
            "stateProvince": "", "country": "", "zone": "",
            "firstName": "", "lastName": ""
        },
        "emailAddress": email,
        "password": PASSWORD,
        "groups": [],
        "language": "en",
        "userName": ""
    }

    data = json.dumps(payload).encode()
    req = urllib.request.Request(API_URL, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("store", STORE)

    try:
        resp = urllib.request.urlopen(req)
        body = json.loads(resp.read())
        print(f"  [{i:02d}/25] Created: {first} {last} ({email}) -> ID {body['id']}")
        created += 1
    except urllib.error.HTTPError as e:
        err = e.read().decode()[:120]
        print(f"  [{i:02d}/25] FAILED: {first} {last} ({email}) -> HTTP {e.code}: {err}")
        failed += 1

print(f"\nDone: {created} created, {failed} failed")
print(f"All passwords: {PASSWORD}")
