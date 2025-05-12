#!/bin/bash
echo "API"
nslookup api.okd.example.com 192.168.40.5
nslookup api-int.okd.example.com 192.168.40.5
echo "*.apps"
nslookup fedora.apps.okd.example.com 192.168.40.5
echo "Bootstrap"
nslookup bootstrap.okd.example.com 192.168.40.5
echo "Reverse lookup API"
nslookup 192.168.40.5
echo "Reverse lookup bootstrap"
nslookup 192.168.40.10
