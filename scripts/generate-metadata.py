#!/usr/bin/env python3
"""Generate Salesforce metadata XML for all Pramaan custom objects and fields."""
import os

BASE = os.path.join(os.path.dirname(__file__), '..', 'force-app', 'main', 'default')

def write(path, content):
    full = os.path.join(BASE, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w') as f:
        f.write(content)
    print(f'  wrote {path}')

def obj_xml(label, plural, api_name, description=''):
    name_type = 'AutoNumber' if api_name == 'Audit_Event__c' else 'Text'
    display_fmt = '{000000}' if api_name == 'Audit_Event__c' else ''
    name_label = 'Event Number' if api_name == 'Audit_Event__c' else f'{label} Name'

    auto_number_block = f'''
        <nameField>
            <displayFormat>AE-{display_fmt}</displayFormat>
            <label>{name_label}</label>
            <type>AutoNumber</type>
        </nameField>''' if name_type == 'AutoNumber' else f'''
        <nameField>
            <label>{name_label}</label>
            <type>Text</type>
        </nameField>'''

    return f'''<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>{label}</label>
    <pluralLabel>{plural}</pluralLabel>
    <description>{description}</description>
    <deploymentStatus>Deployed</deploymentStatus>
    <sharingModel>ReadWrite</sharingModel>{auto_number_block}
</CustomObject>'''

def field_xml(label, api_name, field_type, **kwargs):
    parts = [f'''<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>{api_name}</fullName>
    <label>{label}</label>''']

    if field_type == 'Text':
        length = kwargs.get('length', 255)
        parts.append(f'    <type>Text</type>\n    <length>{length}</length>')
    elif field_type == 'LongTextArea':
        length = kwargs.get('length', 32768)
        parts.append(f'    <type>LongTextArea</type>\n    <length>{length}</length>\n    <visibleLines>5</visibleLines>')
    elif field_type == 'Number':
        precision = kwargs.get('precision', 18)
        scale = kwargs.get('scale', 0)
        parts.append(f'    <type>Number</type>\n    <precision>{precision}</precision>\n    <scale>{scale}</scale>')
    elif field_type == 'Checkbox':
        default = kwargs.get('default', 'false')
        parts.append(f'    <type>Checkbox</type>\n    <defaultValue>{default}</defaultValue>')
    elif field_type == 'DateTime':
        parts.append('    <type>DateTime</type>')
    elif field_type == 'Date':
        parts.append('    <type>Date</type>')
    elif field_type == 'Picklist':
        values = kwargs.get('values', [])
        val_xml = '\n'.join([f'                <value><fullName>{v}</fullName><default>false</default></value>' for v in values])
        parts.append(f'''    <type>Picklist</type>
    <valueSet>
        <restricted>true</restricted>
        <valueSetDefinition>
            <sorted>false</sorted>
{val_xml}
        </valueSetDefinition>
    </valueSet>''')
    elif field_type == 'Lookup':
        ref = kwargs.get('ref')
        rel_name = kwargs.get('rel_name', label.replace(' ', '') + 's')
        parts.append(f'''    <type>Lookup</type>
    <referenceTo>{ref}</referenceTo>
    <relationshipName>{rel_name}</relationshipName>
    <relationshipLabel>{rel_name}</relationshipLabel>''')
    elif field_type == 'MasterDetail':
        ref = kwargs.get('ref')
        rel_name = kwargs.get('rel_name', label.replace(' ', '') + 's')
        parts.append(f'''    <type>MasterDetail</type>
    <referenceTo>{ref}</referenceTo>
    <relationshipName>{rel_name}</relationshipName>
    <relationshipLabel>{rel_name}</relationshipLabel>
    <writeRequiresMasterRead>false</writeRequiresMasterRead>
    <reparentableMasterDetail>false</reparentableMasterDetail>''')
    elif field_type == 'Url':
        parts.append('    <type>Url</type>')
    elif field_type == 'TextArea':
        parts.append('    <type>TextArea</type>')

    if kwargs.get('required'):
        parts.append('    <required>true</required>')
    else:
        parts.append('    <required>false</required>')

    if kwargs.get('unique'):
        parts.append('    <unique>true</unique>')

    if kwargs.get('externalId'):
        parts.append('    <externalId>true</externalId>')

    if kwargs.get('description'):
        parts.append(f'    <description>{kwargs["description"]}</description>')

    parts.append('</CustomField>')
    return '\n'.join(parts)

def cmdt_xml(label, plural, description):
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>{label}</label>
    <pluralLabel>{plural}</pluralLabel>
    <description>{description}</description>
    <visibility>Public</visibility>
</CustomObject>'''

# ── OBJECTS ──

print('Creating objects...')

objects = {
    'AI_Use_Case__c': ('AI Use Case', 'AI Use Cases', 'An Agentforce use case being filed for governance approval'),
    'Agent_Snapshot__c': ('Agent Snapshot', 'Agent Snapshots', 'Point-in-time capture of an agent configuration (AI-BOM)'),
    'Data_Touch__c': ('Data Touch', 'Data Touches', 'A field read or written by an agent action'),
    'Governance_Pack__c': ('Governance Pack', 'Governance Packs', 'A versioned compliance filing for a use case'),
    'Risk_Answer__c': ('Risk Answer', 'Risk Answers', 'An answer to an assessment question with its source'),
    'Clause_Mapping__c': ('Clause Mapping', 'Clause Mappings', 'Maps a regulatory clause to a use case with status and evidence'),
    'Evidence__c': ('Evidence', 'Evidence Records', 'A piece of evidence backing a compliance claim'),
    'Claim_Evidence__c': ('Claim Evidence', 'Claim Evidence Records', 'Junction linking a claim or clause to evidence'),
    'Reviewer_Brief__c': ('Reviewer Brief', 'Reviewer Briefs', 'A lens-specific brief generated for a reviewer'),
    'Review_Finding__c': ('Review Finding', 'Review Findings', 'A finding raised by a reviewer during approval'),
    'Audit_Event__c': ('Audit Event', 'Audit Events', 'A tamper-evident log entry in the governance audit trail'),
}

for api, (label, plural, desc) in objects.items():
    write(f'objects/{api}/{api}.object-meta.xml', obj_xml(label, plural, api, desc))

# ── CUSTOM METADATA TYPE ──

print('Creating custom metadata type...')
write('objects/Reg_Clause__mdt/Reg_Clause__mdt.object-meta.xml', cmdt_xml(
    'Regulatory Clause', 'Regulatory Clauses',
    '76 clauses from 28 Indian regulatory instruments for AI governance'
))

# ── FIELDS ──

print('Creating fields...')

# AI_Use_Case__c fields
uc_fields = [
    ('Agent API Name', 'Agent_API_Name__c', 'Text', {'length': 255, 'description': 'API name of the Agentforce agent'}),
    ('Purpose', 'Purpose__c', 'LongTextArea', {'length': 5000}),
    ('Risk Tier', 'Risk_Tier__c', 'Picklist', {'values': ['Low', 'Medium', 'High', 'Critical']}),
    ('Risk Score', 'Risk_Score__c', 'Number', {'precision': 4, 'scale': 0}),
    ('Status', 'Status__c', 'Picklist', {'values': ['Draft', 'Scanned', 'Mapped', 'In Review', 'Approved', 'Rejected', 'Rework']}),
    ('Sub Sector', 'Sub_Sector__c', 'Picklist', {'values': ['SCB', 'SFB', 'Payments Bank', 'NBFC Upper', 'NBFC Middle', 'NBFC Base', 'HFC', 'Insurer', 'AMC', 'Broker']}),
    ('Audience', 'Audience__c', 'Picklist', {'values': ['Customer', 'Employee', 'Partner']}),
    ('Decision Impact', 'Decision_Impact__c', 'Picklist', {'values': ['Informational', 'Advisory', 'Decisioning', 'Transactional']}),
    ('Autonomy', 'Autonomy__c', 'Picklist', {'values': ['Human-in-loop', 'Human-on-loop', 'Autonomous']}),
    ('Function', 'Function__c', 'Picklist', {'values': ['Origination', 'Collections', 'Deposits', 'Payments', 'Complaints', 'KYC', 'Wealth', 'Insurance Sales', 'Insurance Claims', 'Internal Ops']}),
    ('Channels', 'Channels__c', 'Text', {'length': 255, 'description': 'Comma-separated: Web, App, WhatsApp, SMS, Voice, Slack, API'}),
    ('Data Categories', 'Data_Categories__c', 'Text', {'length': 255, 'description': 'Comma-separated: Personal, Financial, Payment, Aadhaar, Health, Children, Employee'}),
    ('Passport Number', 'Passport_Number__c', 'Text', {'length': 20, 'unique': True, 'externalId': True}),
    ('Passport Issued', 'Passport_Issued__c', 'DateTime', {}),
    ('Owner User', 'Owner_User__c', 'Lookup', {'ref': 'User', 'rel_name': 'OwnedUseCases'}),
    ('Kill Switch Owner', 'Kill_Switch_Owner__c', 'Text', {'length': 255}),
    ('Incident Contact', 'Incident_Contact__c', 'Text', {'length': 255}),
    ('Human Fallback', 'Human_Fallback__c', 'Text', {'length': 255}),
    ('Fallback SLA', 'Fallback_SLA__c', 'Text', {'length': 100}),
    ('Launch Scope', 'Launch_Scope__c', 'Picklist', {'values': ['Pilot', 'Full']}),
    ('Expected Volumes', 'Expected_Volumes__c', 'Text', {'length': 255}),
    ('Disclosure Wording', 'Disclosure_Wording__c', 'TextArea', {}),
    ('Languages', 'Languages__c', 'Text', {'length': 255}),
    ('Legal Ground', 'Legal_Ground__c', 'TextArea', {}),
    ('Retention Period', 'Retention_Period__c', 'Text', {'length': 100}),
    ('Third Parties', 'Third_Parties__c', 'TextArea', {}),
    ('Rollback Plan', 'Rollback_Plan__c', 'TextArea', {}),
    ('Vulnerable Customers', 'Vulnerable_Customers__c', 'Checkbox', {}),
]

for label, api, ftype, kwargs in uc_fields:
    write(f'objects/AI_Use_Case__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Agent_Snapshot__c fields
snap_fields = [
    ('AI Use Case', 'AI_Use_Case__c', 'Lookup', {'ref': 'AI_Use_Case__c', 'rel_name': 'Snapshots'}),
    ('Bot Version Id', 'Bot_Version_Id__c', 'Text', {'length': 18}),
    ('AI BOM JSON', 'AI_BOM_JSON__c', 'LongTextArea', {'length': 131072}),
    ('Snapshot Hash', 'Snapshot_Hash__c', 'Text', {'length': 64}),
    ('Topic Count', 'Topic_Count__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Action Count', 'Action_Count__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Field Count', 'Field_Count__c', 'Number', {'precision': 5, 'scale': 0}),
    ('PII Field Count', 'PII_Field_Count__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Financial Field Count', 'Financial_Field_Count__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Object Count', 'Object_Count__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Read Field Count', 'Read_Field_Count__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Write Field Count', 'Write_Field_Count__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Region', 'Region__c', 'Text', {'length': 100}),
    ('Model Provider', 'Model_Provider__c', 'Text', {'length': 100}),
    ('In Region Only', 'In_Region_Only__c', 'Checkbox', {}),
    ('Scan Duration Ms', 'Scan_Duration_Ms__c', 'Number', {'precision': 10, 'scale': 0}),
    ('Captured At', 'Captured_At__c', 'DateTime', {}),
]

for label, api, ftype, kwargs in snap_fields:
    write(f'objects/Agent_Snapshot__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Data_Touch__c fields
dt_fields = [
    ('Agent Snapshot', 'Agent_Snapshot__c', 'Lookup', {'ref': 'Agent_Snapshot__c', 'rel_name': 'DataTouches'}),
    ('Object Name', 'Object_Name__c', 'Text', {'length': 255}),
    ('Field Name', 'Field_Name__c', 'Text', {'length': 255}),
    ('Access Type', 'Access_Type__c', 'Picklist', {'values': ['Read', 'Write']}),
    ('Compliance Group', 'Compliance_Group__c', 'Text', {'length': 255}),
    ('Security Classification', 'Security_Classification__c', 'Text', {'length': 255}),
    ('Action Name', 'Action_Name__c', 'Text', {'length': 255}),
    ('Is PII', 'Is_PII__c', 'Checkbox', {}),
    ('Is Financial', 'Is_Financial__c', 'Checkbox', {}),
    ('Is Aadhaar', 'Is_Aadhaar__c', 'Checkbox', {}),
]

for label, api, ftype, kwargs in dt_fields:
    write(f'objects/Data_Touch__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Governance_Pack__c fields
gp_fields = [
    ('AI Use Case', 'AI_Use_Case__c', 'Lookup', {'ref': 'AI_Use_Case__c', 'rel_name': 'GovernancePacks'}),
    ('Agent Snapshot', 'Agent_Snapshot__c', 'Lookup', {'ref': 'Agent_Snapshot__c', 'rel_name': 'GovernancePacks'}),
    ('Version', 'Version__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Pack Status', 'Pack_Status__c', 'Picklist', {'values': ['Draft', 'Generating', 'Ready', 'Filed', 'All Approved', 'Rejected']}),
    ('Filed At', 'Filed_At__c', 'DateTime', {}),
    ('Passport Number', 'Passport_Number__c', 'Text', {'length': 20}),
    ('Approved Hash', 'Approved_Hash__c', 'Text', {'length': 64}),
    ('Passport Issued At', 'Passport_Issued_At__c', 'DateTime', {}),
    ('Clauses Total', 'Clauses_Total__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Clauses Met', 'Clauses_Met__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Clauses Gap', 'Clauses_Gap__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Clauses NA', 'Clauses_NA__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Gates Required', 'Gates_Required__c', 'Number', {'precision': 2, 'scale': 0}),
    ('Gates Approved', 'Gates_Approved__c', 'Number', {'precision': 2, 'scale': 0}),
]

for label, api, ftype, kwargs in gp_fields:
    write(f'objects/Governance_Pack__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Risk_Answer__c fields
ra_fields = [
    ('AI Use Case', 'AI_Use_Case__c', 'Lookup', {'ref': 'AI_Use_Case__c', 'rel_name': 'RiskAnswers'}),
    ('Question Key', 'Question_Key__c', 'Text', {'length': 100}),
    ('Answer', 'Answer__c', 'LongTextArea', {'length': 10000}),
    ('Source', 'Source__c', 'Picklist', {'values': ['X-Ray', 'Locker', 'Interview', 'Draft']}),
    ('Evidence Ref', 'Evidence_Ref__c', 'Lookup', {'ref': 'Evidence__c', 'rel_name': 'RiskAnswers'}),
]

for label, api, ftype, kwargs in ra_fields:
    write(f'objects/Risk_Answer__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Clause_Mapping__c fields
cm_fields = [
    ('Governance Pack', 'Governance_Pack__c', 'Lookup', {'ref': 'Governance_Pack__c', 'rel_name': 'ClauseMappings'}),
    ('Clause DeveloperName', 'Clause_DeveloperName__c', 'Text', {'length': 80, 'description': 'DeveloperName of the Reg_Clause__mdt record'}),
    ('Why It Applies', 'Why_It_Applies__c', 'LongTextArea', {'length': 5000}),
    ('Mapping Status', 'Mapping_Status__c', 'Picklist', {'values': ['Met', 'Partial', 'Gap', 'Inherited', 'N/A', 'Risk Accepted']}),
    ('Owner User', 'Owner_User__c', 'Lookup', {'ref': 'User', 'rel_name': 'ClauseMappings'}),
    ('Risk Accepted Until', 'Risk_Accepted_Until__c', 'Date', {}),
    ('Fix Due Date', 'Fix_Due_Date__c', 'Date', {}),
    ('Fix Description', 'Fix_Description__c', 'TextArea', {}),
    ('Regulator', 'Regulator__c', 'Text', {'length': 20}),
    ('Clause Reference', 'Clause_Reference__c', 'Text', {'length': 255}),
    ('Binding Status', 'Binding_Status__c', 'Picklist', {'values': ['In force', 'From future date', 'Draft', 'Non-binding', 'Advisory']}),
]

for label, api, ftype, kwargs in cm_fields:
    write(f'objects/Clause_Mapping__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Evidence__c fields
ev_fields = [
    ('Evidence Type', 'Evidence_Type__c', 'Picklist', {'values': ['Metadata', 'Policy', 'Consent', 'Test', 'Audit', 'Platform']}),
    ('Scope', 'Scope__c', 'Picklist', {'values': ['Platform', 'Bank', 'Use Case']}),
    ('Source Reference', 'Source_Reference__c', 'LongTextArea', {'length': 5000}),
    ('Valid Until', 'Valid_Until__c', 'Date', {}),
    ('Evidence Hash', 'Evidence_Hash__c', 'Text', {'length': 64}),
    ('AI Use Case', 'AI_Use_Case__c', 'Lookup', {'ref': 'AI_Use_Case__c', 'rel_name': 'EvidenceRecords'}),
    ('Description', 'Description__c', 'TextArea', {}),
]

for label, api, ftype, kwargs in ev_fields:
    write(f'objects/Evidence__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Claim_Evidence__c fields (junction)
ce_fields = [
    ('Clause Mapping', 'Clause_Mapping__c', 'Lookup', {'ref': 'Clause_Mapping__c', 'rel_name': 'ClaimEvidenceLinks'}),
    ('Evidence', 'Evidence__c', 'Lookup', {'ref': 'Evidence__c', 'rel_name': 'ClaimEvidenceLinks'}),
    ('Reviewer Brief', 'Reviewer_Brief__c', 'Lookup', {'ref': 'Reviewer_Brief__c', 'rel_name': 'ClaimEvidenceLinks'}),
]

for label, api, ftype, kwargs in ce_fields:
    write(f'objects/Claim_Evidence__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Reviewer_Brief__c fields
rb_fields = [
    ('Governance Pack', 'Governance_Pack__c', 'Lookup', {'ref': 'Governance_Pack__c', 'rel_name': 'ReviewerBriefs'}),
    ('Lens', 'Lens__c', 'Picklist', {'values': ['AI Risk Committee', 'Architecture', 'Security', 'Compliance', 'Legal', 'Executive']}),
    ('Brief Content', 'Brief_Content__c', 'LongTextArea', {'length': 131072}),
    ('Claims Total', 'Claims_Total__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Claims With Receipts', 'Claims_With_Receipts__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Claims Blocked', 'Claims_Blocked__c', 'Number', {'precision': 5, 'scale': 0}),
    ('Prompt Template', 'Prompt_Template__c', 'Text', {'length': 255}),
    ('Generation Id', 'Generation_Id__c', 'Text', {'length': 100}),
    ('Approval Status', 'Approval_Status__c', 'Picklist', {'values': ['Not Filed', 'Pending', 'Approved', 'Rejected', 'Rework']}),
    ('Reviewer', 'Reviewer__c', 'Lookup', {'ref': 'User', 'rel_name': 'AssignedBriefs'}),
    ('Decision Date', 'Decision_Date__c', 'DateTime', {}),
    ('Reviewer Comments', 'Reviewer_Comments__c', 'LongTextArea', {'length': 10000}),
    ('Brief Hash', 'Brief_Hash__c', 'Text', {'length': 64}),
]

for label, api, ftype, kwargs in rb_fields:
    write(f'objects/Reviewer_Brief__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Review_Finding__c fields
rf_fields = [
    ('Reviewer Brief', 'Reviewer_Brief__c', 'Lookup', {'ref': 'Reviewer_Brief__c', 'rel_name': 'ReviewFindings'}),
    ('Lens', 'Lens__c', 'Picklist', {'values': ['AI Risk Committee', 'Architecture', 'Security', 'Compliance', 'Legal']}),
    ('Severity', 'Severity__c', 'Picklist', {'values': ['Critical', 'High', 'Medium', 'Low', 'Info']}),
    ('Clause Reference', 'Clause_Reference__c', 'Text', {'length': 255}),
    ('Finding Description', 'Finding_Description__c', 'LongTextArea', {'length': 10000}),
    ('Fix Required', 'Fix_Required__c', 'TextArea', {}),
    ('Finding Status', 'Finding_Status__c', 'Picklist', {'values': ['Open', 'Fixed', 'Accepted', 'Closed']}),
]

for label, api, ftype, kwargs in rf_fields:
    write(f'objects/Review_Finding__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Audit_Event__c fields
ae_fields = [
    ('Governance Pack', 'Governance_Pack__c', 'Lookup', {'ref': 'Governance_Pack__c', 'rel_name': 'AuditEvents'}),
    ('Sequence', 'Sequence__c', 'Number', {'precision': 10, 'scale': 0}),
    ('Event Type', 'Event_Type__c', 'Picklist', {'values': ['X-Ray', 'Interview', 'Mapping', 'Filing', 'Approval', 'Rejection', 'Rework', 'Passport', 'Drift', 'Activation']}),
    ('Actor', 'Actor__c', 'Text', {'length': 255}),
    ('Payload', 'Payload__c', 'LongTextArea', {'length': 131072}),
    ('Previous Hash', 'Previous_Hash__c', 'Text', {'length': 64}),
    ('Event Hash', 'Event_Hash__c', 'Text', {'length': 64}),
    ('Event Timestamp', 'Event_Timestamp__c', 'DateTime', {}),
]

for label, api, ftype, kwargs in ae_fields:
    write(f'objects/Audit_Event__c/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# Reg_Clause__mdt fields
rc_fields = [
    ('Regulator', 'Regulator__c', 'Text', {'length': 20}),
    ('Instrument', 'Instrument__c', 'Text', {'length': 255}),
    ('Legacy Citation', 'Legacy_Citation__c', 'Text', {'length': 255}),
    ('Reference', 'Reference__c', 'Text', {'length': 255}),
    ('Obligation', 'Obligation__c', 'LongTextArea', {'length': 10000}),
    ('Applies When', 'Applies_When__c', 'LongTextArea', {'length': 5000, 'description': 'Rule expression for applicability engine'}),
    ('Evidence Types', 'Evidence_Types__c', 'Text', {'length': 255}),
    ('Evidence Scope', 'Evidence_Scope__c', 'Picklist', {'values': ['Platform', 'Bank', 'Use Case']}),
    ('Lens', 'Lens__c', 'Picklist', {'values': ['Risk', 'Architecture', 'Security', 'Compliance', 'Legal']}),
    ('Binding Status', 'Binding_Status__c', 'Picklist', {'values': ['In force', 'From future date', 'Draft', 'Non-binding', 'Advisory']}),
    ('Effective From', 'Effective_From__c', 'Date', {}),
    ('Effective To', 'Effective_To__c', 'Date', {}),
    ('Verification Tag', 'Verification_Tag__c', 'Picklist', {'values': ['P', 'S', 'I', 'U']}),
    ('Mentions AI', 'Mentions_AI__c', 'Checkbox', {}),
    ('Source URL', 'Source_URL__c', 'Url', {}),
    ('Evidence Hint', 'Evidence_Hint__c', 'LongTextArea', {'length': 5000}),
]

for label, api, ftype, kwargs in rc_fields:
    write(f'objects/Reg_Clause__mdt/fields/{api}.field-meta.xml', field_xml(label, api, ftype, **kwargs))

# ── TABS ──
print('Creating tabs...')

tab_objects = [
    ('AI_Use_Case__c', 'Custom60'),
    ('Governance_Pack__c', 'Custom61'),
    ('Evidence__c', 'Custom62'),
    ('Reviewer_Brief__c', 'Custom63'),
    ('Audit_Event__c', 'Custom64'),
]

for obj, motif in tab_objects:
    write(f'tabs/{obj}.tab-meta.xml', f'''<?xml version="1.0" encoding="UTF-8"?>
<CustomTab xmlns="http://soap.sforce.com/2006/04/metadata">
    <customObject>true</customObject>
    <motif>{motif}</motif>
</CustomTab>''')

print('\nDone! All metadata files generated.')
