# 💼 Micro-Task-Payments

A decentralized platform for small task management and payments on the Stacks blockchain. Create tasks, assign workers, handle disputes, and process secure payments with built-in escrow functionality.

## ✨ Features

- 🎯 **Task Creation & Management**: Create tasks with deadlines and payment amounts
- 👥 **Worker Applications**: Apply for tasks with custom messages
- 🔒 **Secure Escrow**: Payments held in contract until task completion
- ⭐ **Rating System**: Rate workers and creators (1-5 stars)
- 🛡️ **Dispute Resolution**: Built-in dispute handling by contract owner
- 📊 **User Profiles**: Track earnings, completion rates, and ratings
- 💰 **Platform Fee**: Configurable platform fee system (default 2.5%)

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet configured

### Installation
```bash
git clone <repository-url>
cd Micro-Task-Payments
clarinet check
```

## 📖 Contract Functions

### 🎯 Task Management

#### Create Task
```clarity
(contract-call? .micro-task-payments create-task 
  "Write documentation" 
  "Need help writing API documentation for our project" 
  u1000 
  u500000) ;; 0.5 STX
```

#### Apply for Task
```clarity
(contract-call? .micro-task-payments apply-for-task 
  u1 
  "I have 5 years experience in technical writing")
```

#### Assign Task
```clarity
(contract-call? .micro-task-payments assign-task 
  u1 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### Complete Task
```clarity
(contract-call? .micro-task-payments complete-task u1)
```

#### Approve & Rate
```clarity
(contract-call? .micro-task-payments approve-completion u1 u5) ;; 5-star rating
```

### 🛡️ Dispute Resolution

#### Create Dispute
```clarity
(contract-call? .micro-task-payments dispute-task 
  u1 
  "Task requirements were not met as specified")
```

#### Resolve Dispute (Owner Only)
```clarity
;; Resolve in favor of creator
(contract-call? .micro-task-payments resolve-dispute-creator u1)

;; Resolve in favor of assignee
(contract-call? .micro-task-payments resolve-dispute-assignee u1)
```

### 📊 Data Queries

#### Get Task Details
```clarity
(contract-call? .micro-task-payments get-task u1)
```

#### Get User Profile
```clarity
(contract-call? .micro-task-payments get-user-profile 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### Get Application
```clarity
(contract-call? .micro-task-payments get-task-application u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 💰 Payment Flow

1. **Task Creation**: Payment is escrowed in the contract
2. **Task Completion**: Worker marks task as completed
3. **Approval**: Creator approves and rates the work
4. **Payment Release**: Worker receives payment minus platform fee
5. **Platform Fee**: Small percentage goes to contract owner

## 🔧 Admin Functions

### Set Platform Fee
```clarity
(contract-call? .micro-task-payments set-platform-fee u300) ;; 3%
```

## 📋 Task Statuses

- `"open"` - Available for applications
- `"assigned"` - Worker assigned, in progress
- `"completed"` - Marked complete by worker
- `"paid"` - Payment released to worker
- `"disputed"` - Under dispute resolution
- `"cancelled"` - Cancelled by creator

## ⚡ Error Codes

- `u100` - Not authorized
- `u101` - Task not found
- `u102` - Task already assigned
- `u103` - Task not assigned
- `u104` - Task already completed
- `u105` - Task not completed
- `u106` - Insufficient payment
- `u107` - Invalid status
- `u108` - Deadline passed
- `u109` - Deadline not passed
- `u110` - Already rated
- `u111` - Invalid rating

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```



## 📄 License

This project is licensed under the MIT License.

