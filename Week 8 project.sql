-- Library Management System Database
-- Created by: Database Administrator
-- Date: 2024-01-15

-- Create the database
DROP DATABASE IF EXISTS library_management;
CREATE DATABASE library_management;
USE library_management;

-- 1. Library Branch Table
CREATE TABLE library_branch (
    branch_id INT AUTO_INCREMENT PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    opening_hours VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Staff Table
CREATE TABLE staff (
    staff_id INT AUTO_INCREMENT PRIMARY KEY,
    branch_id INT NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    position VARCHAR(50) NOT NULL,
    salary DECIMAL(10,2) NOT NULL CHECK (salary > 0),
    hire_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (branch_id) REFERENCES library_branch(branch_id) ON DELETE RESTRICT
);

-- 3. Member Table
CREATE TABLE member (
    member_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    address VARCHAR(255) NOT NULL,
    date_of_birth DATE NOT NULL,
    membership_type ENUM('Student', 'Faculty', 'Public') NOT NULL,
    membership_start_date DATE NOT NULL,
    membership_end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE CHECK (membership_end_date >= CURDATE()),
    max_books_allowed INT DEFAULT 5 CHECK (max_books_allowed BETWEEN 1 AND 10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Author Table
CREATE TABLE author (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_year YEAR,
    death_year YEAR,
    nationality VARCHAR(50),
    biography TEXT,
    CONSTRAINT chk_years CHECK (death_year IS NULL OR birth_year <= death_year)
);

-- 5. Publisher Table
CREATE TABLE publisher (
    publisher_id INT AUTO_INCREMENT PRIMARY KEY,
    publisher_name VARCHAR(100) UNIQUE NOT NULL,
    address VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(100) UNIQUE NOT NULL,
    website VARCHAR(200)
);

-- 6. Book Table
CREATE TABLE book (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    isbn VARCHAR(17) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    publisher_id INT NOT NULL,
    publication_year YEAR NOT NULL CHECK (publication_year <= YEAR(CURDATE())),
    edition INT DEFAULT 1 CHECK (edition >= 1),
    category VARCHAR(50) NOT NULL,
    language VARCHAR(30) DEFAULT 'English',
    page_count INT CHECK (page_count > 0),
    description TEXT,
    price DECIMAL(8,2) CHECK (price >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (publisher_id) REFERENCES publisher(publisher_id) ON DELETE RESTRICT
);

-- 7. Book-Author Relationship Table (Many-to-Many)
CREATE TABLE book_author (
    book_id INT NOT NULL,
    author_id INT NOT NULL,
    PRIMARY KEY (book_id, author_id),
    FOREIGN KEY (book_id) REFERENCES book(book_id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES author(author_id) ON DELETE CASCADE
);

-- 8. Book Copy Table (One-to-Many with Book)
CREATE TABLE book_copy (
    copy_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    branch_id INT NOT NULL,
    acquisition_date DATE NOT NULL,
    copy_status ENUM('Available', 'Checked Out', 'Under Maintenance', 'Lost') DEFAULT 'Available',
    shelf_location VARCHAR(20) NOT NULL,
    book_condition ENUM('New', 'Good', 'Fair', 'Poor') DEFAULT 'Good',
    last_maintenance_date DATE,
    FOREIGN KEY (book_id) REFERENCES book(book_id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES library_branch(branch_id) ON DELETE CASCADE
);

-- 9. Loan Table
CREATE TABLE loan (
    loan_id INT AUTO_INCREMENT PRIMARY KEY,
    copy_id INT NOT NULL,
    member_id INT NOT NULL,
    staff_id INT NOT NULL,
    loan_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    late_fee DECIMAL(6,2) DEFAULT 0 CHECK (late_fee >= 0),
    loan_status ENUM('Active', 'Returned', 'Overdue') DEFAULT 'Active',
    CHECK (due_date > loan_date),
    CHECK (return_date IS NULL OR return_date >= loan_date),
    FOREIGN KEY (copy_id) REFERENCES book_copy(copy_id) ON DELETE RESTRICT,
    FOREIGN KEY (member_id) REFERENCES member(member_id) ON DELETE RESTRICT,
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON DELETE RESTRICT
);

-- 10. Reservation Table
CREATE TABLE reservation (
    reservation_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    member_id INT NOT NULL,
    reservation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reservation_status ENUM('Pending', 'Fulfilled', 'Cancelled') DEFAULT 'Pending',
    priority INT DEFAULT 1 CHECK (priority >= 1),
    notes TEXT,
    FOREIGN KEY (book_id) REFERENCES book(book_id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES member(member_id) ON DELETE CASCADE,
    UNIQUE KEY unique_active_reservation (book_id, member_id, reservation_status)
);

-- 11. Fine Table
CREATE TABLE fine (
    fine_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    loan_id INT,
    fine_amount DECIMAL(6,2) NOT NULL CHECK (fine_amount >= 0),
    fine_date DATE NOT NULL,
    reason VARCHAR(255) NOT NULL,
    paid_amount DECIMAL(6,2) DEFAULT 0 CHECK (paid_amount >= 0 AND paid_amount <= fine_amount),
    payment_date DATE,
    fine_status ENUM('Pending', 'Partially Paid', 'Paid') DEFAULT 'Pending',
    FOREIGN KEY (member_id) REFERENCES member(member_id) ON DELETE CASCADE,
    FOREIGN KEY (loan_id) REFERENCES loan(loan_id) ON DELETE SET NULL
);

-- 12. Audit Log Table
CREATE TABLE audit_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INT NOT NULL,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_values JSON,
    new_values JSON,
    changed_by INT NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (changed_by) REFERENCES staff(staff_id) ON DELETE RESTRICT
);

-- Create indexes for better performance
CREATE INDEX idx_book_title ON book(title);
CREATE INDEX idx_book_category ON book(category);
CREATE INDEX idx_member_email ON member(email);
CREATE INDEX idx_loan_due_date ON loan(due_date);
CREATE INDEX idx_loan_status ON loan(loan_status);
CREATE INDEX idx_copy_status ON book_copy(copy_status);
CREATE INDEX idx_fine_status ON fine(fine_status);
CREATE INDEX idx_reservation_status ON reservation(reservation_status);

-- Create a view for active loans with member and book details
CREATE VIEW active_loans_view AS
SELECT 
    l.loan_id,
    m.first_name AS member_first_name,
    m.last_name AS member_last_name,
    b.title AS book_title,
    bc.copy_id,
    lb.branch_name,
    l.loan_date,
    l.due_date,
    DATEDIFF(CURDATE(), l.due_date) AS days_overdue
FROM loan l
JOIN member m ON l.member_id = m.member_id
JOIN book_copy bc ON l.copy_id = bc.copy_id
JOIN book b ON bc.book_id = b.book_id
JOIN library_branch lb ON bc.branch_id = lb.branch_id
WHERE l.loan_status = 'Active';

-- Create a view for available books
CREATE VIEW available_books_view AS
SELECT 
    b.book_id,
    b.title,
    b.isbn,
    a.first_name AS author_first_name,
    a.last_name AS author_last_name,
    bc.copy_id,
    lb.branch_name,
    bc.shelf_location
FROM book b
JOIN book_author ba ON b.book_id = ba.book_id
JOIN author a ON ba.author_id = a.author_id
JOIN book_copy bc ON b.book_id = bc.book_id
JOIN library_branch lb ON bc.branch_id = lb.branch_id
WHERE bc.copy_status = 'Available';

-- Insert sample data
INSERT INTO library_branch (branch_name, address, phone, email, opening_hours) VALUES
('Central Library', 'Kenyatta Avenue, Nairobi', '0722345678', 'central@library.com', 'Mon-Fri: 9AM-9PM, Sat-Sun: 10AM-6PM'),
('North Branch', 'Magadi Road, Rongai', '0733678901', 'north@library.com', 'Mon-Fri: 10AM-8PM, Sat: 10AM-5PM'),
('South Branch', 'Thika Road, Thika', '0743234567', 'south@library.com', 'Mon-Fri: 9AM-7PM, Sat-Sun: 12PM-5PM');

INSERT INTO publisher (publisher_name, address, phone, email, website) VALUES
('Penguin Random House', 'Moi Avenue, Nairobi', '0721765432', 'info@penguinrandomhouse.com', 'https://www.penguinrandomhouse.com'),
('HarperCollins', 'Tom Mboya, Nairobi', '0734098765', 'contact@harpercollins.com', 'https://www.harpercollins.com'),
('Simon & Schuster', 'University Way, Nairobi', '0728378654', 'info@simonandschuster.com', 'https://www.simonandschuster.com');

-- Display table relationships information
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'library_management' 
AND REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY TABLE_NAME, CONSTRAINT_NAME;