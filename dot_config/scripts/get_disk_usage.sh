#!/bin/bash
df -h / | tail -1 | awk '{print $5}'
