with open('Astar/Features/Main/MainFeature.swift', 'r') as f:
    text = f.read()

text = text.replace('__import__("CloudKit").CKRecord.ID', 'CKRecord.ID')

if 'import CloudKit' not in text:
    text = 'import CloudKit\n' + text

with open('Astar/Features/Main/MainFeature.swift', 'w') as f:
    f.write(text)

