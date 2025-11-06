# 🧩 User Story: Enhanced Password Policies with Historical Tracking and Renewal

**As a** system administrator and security-conscious user  
**I want** enhanced password policies with historical tracking and periodic renewal requirements  
**So that** the system maintains high security standards and protects user accounts from unauthorized access  

---

## 💡 Business Value

- **Security Enhancement:** Reduces risk of account compromise through weak passwords  
- **Compliance:** Meets industry security standards and regulatory requirements  
- **User Account Protection:** Prevents password reuse and ensures regular password updates  
- **Audit Trail:** Maintains comprehensive logging for security audits  

---

## ✅ Acceptance Criteria

### **AC1: Password Complexity Requirements**

**Given** a user is creating or changing their password  
**When** they enter a new password  
**Then** the system must enforce the following requirements:

- Minimum **8 characters** in length  
- At least **1 lowercase letter** (`a–z`)  
- At least **1 uppercase letter** (`A–Z`)  
- At least **1 number** (`0–9`)  
- At least **1 special character** (`!@#$%^&*()_+-=[]{}|;:,.<>?`)  

And the system displays **real-time validation feedback** for each requirement.

---

### **AC2: Password History Management**

**Given** a user is changing their password  
**When** they submit a new password  
**Then** the system must:

- Check against the **last 5 passwords** used by the user  
- Reject the new password if it matches any of the previous 5  
- Store the new password **hash** in the password history  
- Maintain only the **5 most recent password hashes** (remove older entries)  

And display an appropriate error message:  
> “You cannot reuse any of your last 5 passwords.”

---

### **AC3: Password Change Logging and Periodic Renewal**

**Given** a user changes their password  
**When** the password change is successful  
**Then** the system must:

- Log the password change event with **timestamp** and **user ID**  
- Set the **password expiration date** to **6 months** from the change date  
- Send a **confirmation notification** to the user  

**And**  
**Given** a user's password is older than 6 months  
**When** they attempt to access the system  
**Then** they must be redirected to the **mandatory password change page**  

---

### **AC4: Login-Time Password Policy Enforcement with Legacy User Support**

**Given** a user with an existing password that doesn’t meet new policy requirements  
**When** they successfully authenticate  
**Then** the system must:

- Detect that the current password doesn’t meet new requirements  
- Redirect the user to the **mandatory password change page**  
- Prevent access to other system functionality until updated  

#### 🧓 Legacy User Exception

**Given** a user who has never changed their password before (`last_password_update = null`)  
**When** they attempt to log in with their original password  
**Then** the system must:

- Allow login even if the password doesn’t meet new requirements  
- **Not enforce** the 6-month expiration rule for this login  
- Set `last_password_update = null` for all users during migration  

#### 🔁 Post-First-Change Enforcement

**Given** a user who has changed their password at least once (`last_password_update ≠ null`)  
**When** they attempt to log in  
**Then** the system must:

- Apply full password complexity validation  
- Enforce the 6-month expiration rule  
- Redirect to **mandatory password change** if either rule is violated  

---

### **AC5: Mandatory Password Change Interface**

**Given** a user is on the mandatory password change page  
**When** they view the page  
**Then** the interface must include:

- **New Password** field (with show/hide toggle)  
- **Repeat New Password** field (with show/hide toggle)  
- **Next** button (enabled only when both fields are valid and match)  
- **Logout** button (positioned to the left of Next button)  
- **Password requirements tooltip** (always visible or accessible via info icon)  

**And**  
- When the user clicks **Logout**, they are logged out and redirected to the login page  
- When the user clicks **Next** with valid passwords, the password is updated and they proceed to the main application  

---

### **AC6: Password Requirements Tooltip**

**Given** a user is on any password change interface  
**When** they view the password requirements  
**Then** a tooltip or help text must display:

#### Password Requirements
✅ At least 8 characters long  
✅ Contains at least 1 lowercase letter (`a–z`)  
✅ Contains at least 1 uppercase letter (`A–Z`)  
✅ Contains at least 1 number (`0–9`)  
✅ Contains at least 1 special character (`!@#$%^&*()_+-=[]{}|;:,.<>?`)  
✅ Cannot be one of your last 5 passwords  

And the tooltip updates in **real time** to show which requirements are met.

---

## ⚙️ Implementation Details

### **Existing User Migration**
- During deployment, set `last_password_update = null` for all existing users  
- Ensures existing users can log in with current passwords  
- Once they change their password, full policy enforcement begins  

### **Password History Initialization**
- For users who have never changed passwords, password history starts **empty**  
- History tracking begins **after the first change**

### **Grace Period Logic**
| Condition | Enforcement |
|------------|--------------|
| `last_password_update = null` | No expiration enforcement; complexity validation only on change |
| `last_password_update ≠ null` | Full enforcement including 6-month expiration |

---

## 🔒 Security Considerations

- All passwords must be hashed using **bcrypt** (or equivalent)  
- Password history entries must be **securely hashed**  
- Log all password-related events for **security auditing**  
- Maintain **backward compatibility** for existing users while ensuring improved security  
