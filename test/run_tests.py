import urllib.request
import urllib.error
import json
import time

def post(url, data=None, headers=None):
    if headers is None:
        headers = {}
    headers.setdefault('Content-Type', 'application/json')
    headers.setdefault('Accept', 'application/json')
    body = json.dumps(data).encode('utf-8') if data is not None else b''
    req = urllib.request.Request(url, data=body, headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        raw = e.read().decode('utf-8')
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw

def get(url, headers=None):
    if headers is None:
        headers = {}
    headers.setdefault('Accept', 'application/json')
    req = urllib.request.Request(url, headers=headers, method='GET')
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        raw = e.read().decode('utf-8')
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw

base = 'http://127.0.0.1:5173'
results = []

def record(case_no, name, passed, details):
    results.append({'no': case_no, 'name': name, 'pass': passed, 'details': details})

# Test 1: Register using valid details
test_email = f"student_{int(time.time())}@demo.com"
s1, r1 = post(f"{base}/register.php", {'name': 'John Doe', 'email': test_email, 'password': 'password123'})
record(1, 'Register using valid details', s1 == 201 and r1.get('success') is True, f"Status: {s1}, Response: {r1}")

# Test 2: Register using existing email
s2, r2 = post(f"{base}/register.php", {'name': 'John Duplicate', 'email': test_email, 'password': 'password123'})
record(2, 'Register using existing email', s2 == 409 and 'already registered' in r2.get('message', ''), f"Status: {s2}, Response: {r2}")

# Test 3: Submit incomplete/invalid registration
s3a, r3a = post(f"{base}/register.php", {'name': '', 'email': test_email, 'password': 'password123'})
s3b, r3b = post(f"{base}/register.php", {'name': 'John', 'email': 'not-an-email', 'password': 'password123'})
s3c, r3c = post(f"{base}/register.php", {'name': 'John', 'email': 'valid@demo.com', 'password': '123'})
t3_pass = (s3a == 400 and s3b == 400 and s3c == 400)
record(3, 'Submit incomplete/invalid registration', t3_pass, f"Empty: {s3a}, Bad email: {s3b}, Short pwd: {s3c}")

# Test 4: Login with correct credentials
s4, r4 = post(f"{base}/login.php", {'email': test_email, 'password': 'password123'})
student_token = r4.get('token')
record(4, 'Login with correct credentials', s4 == 200 and student_token is not None, f"Status: {s4}, Token: {student_token[:10]}...")

# Test 5: Login with incorrect credentials
s5a, r5a = post(f"{base}/login.php", {'email': test_email, 'password': 'wrongpassword'})
s5b, r5b = post(f"{base}/login.php", {'email': 'nonexistent@demo.com', 'password': 'password123'})
record(5, 'Login with incorrect credentials', s5a == 401 and s5b == 401, f"Wrong pwd: {s5a}, Nonexistent: {s5b}")

# Test 6: Login using both roles
s6_admin, r6_admin = post(f"{base}/login.php", {'email': 'admin@demo.com', 'password': 'admin123'})
admin_tok = r6_admin.get('token')
s6_prof_admin, r6_prof_admin = get(f"{base}/profile.php", {'Authorization': f"Bearer {admin_tok}"})
admin_role = r6_prof_admin.get('user', {}).get('role')

s6_prof_stu, r6_prof_stu = get(f"{base}/profile.php", {'Authorization': f"Bearer {student_token}"})
stu_role = r6_prof_stu.get('user', {}).get('role')
record(6, 'Login using both roles', admin_role == 'Admin' and stu_role == 'Student', f"Admin role: {admin_role}, Student role: {stu_role}")

# Test 7: Reopen app with valid session
s7, r7 = get(f"{base}/profile.php", {'Authorization': f"Bearer {student_token}"})
record(7, 'Reopen app with valid session', s7 == 200 and r7.get('user', {}).get('email') == test_email, f"Status: {s7}, User: {r7.get('user', {}).get('name')}")

# Test 8: Request profile without authentication
s8a, r8a = get(f"{base}/profile.php")
s8b, r8b = get(f"{base}/profile.php", {'Authorization': 'Bearer fake_invalid_token_12345'})
record(8, 'Request profile without authentication', s8a == 401 and s8b == 401, f"No auth: {s8a}, Bad token: {s8b}")

# Test 9: Logout and reopen application
s9_out, r9_out = post(f"{base}/logout.php", headers={'Authorization': f"Bearer {student_token}"})
s9_after, r9_after = get(f"{base}/profile.php", {'Authorization': f"Bearer {student_token}"})
record(9, 'Logout and reopen application', s9_out == 200 and s9_after == 401, f"Logout status: {s9_out}, Recheck profile: {s9_after} (Expected 401)")

print('========================================================================')
print('                 ASSIGNMENT 2 COMPREHENSIVE TEST SUITE                  ')
print('========================================================================')
all_pass = True
for r in results:
    status_str = 'PASS' if r['pass'] else 'FAIL'
    if not r['pass']:
        all_pass = False
    print(f"Test {r['no']}: [{status_str}] {r['name']}")
    print(f"         Details: {r['details']}")
print('========================================================================')
print(f"OVERALL RESULT: {'ALL 9 TESTS PASSED' if all_pass else 'SOME TESTS FAILED'}")
print('========================================================================')
