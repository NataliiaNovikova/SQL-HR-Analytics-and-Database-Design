/* ============================================================================
   PROJECT: EdTech Course Management Database Design & Data Quality Audit
   AUTHOR: Nataliia Novikova
   DESCRIPTION: End-to-end relational schema design (DDL), transactional data 
                ingestion (DML), workload reporting, and duplicate detection.
============================================================================ */

/* ----------------------------------------------------------------------------
   TASK 1: Relational Schema Architecture & Constraints (DDL)
   Business Requirement: Design a normalized 3-table database for an EdTech 
   platform tracking teachers, courses, and student enrollments with referential 
   integrity and date validation rules.
   SQL Techniques: CREATE DATABASE/TABLE, Primary & Foreign Keys, CHECK Constraint
---------------------------------------------------------------------------- */
CREATE DATABASE IF NOT EXISTS course_management;
USE course_management;

CREATE TABLE IF NOT EXISTS teachers (
    teacher_no INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,      
    last_name VARCHAR(50) NOT NULL,       
    phone_number VARCHAR(10)              
);

CREATE TABLE IF NOT EXISTS courses (
    course_no INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,             
    start_date DATE,
    end_date DATE,
    CHECK (end_date IS NULL OR start_date IS NOT NULL)              
);

CREATE TABLE IF NOT EXISTS students (
    student_no INT AUTO_INCREMENT PRIMARY KEY,
    teacher_no INT NOT NULL,
    course_no INT NOT NULL,
    first_name VARCHAR(50) NOT NULL,      
    last_name VARCHAR(50) NOT NULL,        
    email VARCHAR(100),
    birth_date DATE, 
    FOREIGN KEY (teacher_no) REFERENCES teachers(teacher_no),
    FOREIGN KEY (course_no) REFERENCES courses(course_no)
);


/* ----------------------------------------------------------------------------
   TASK 2: Transactional Data Population (DML)
   Business Requirement: Populate all entities with initial production-like 
   records inside an atomic transaction to guarantee consistency.
   SQL Techniques: START TRANSACTION, INSERT INTO, COMMIT
---------------------------------------------------------------------------- */
START TRANSACTION;

INSERT INTO teachers (first_name, last_name, phone_number) VALUES
('Edna', 'Townsend', '0631245789'),
('Charles', 'Dawson', NULL),
('Wendy', 'Williams', '0674519832'),
('Tonya', 'Anderson', NULL),
('Raymond', 'Edwards', '0938527416'),
('James', 'Henry', '0681593742'),
('Stephanie', 'Douglas', '0996325874');

INSERT INTO courses (name, start_date, end_date) VALUES
('Python for Beginners', '2025-02-25', NULL),
('Google SEO Masterclass', '2024-01-27', '2025-06-15'),
('AI & Machine Learning', '2026-03-21', '2026-05-05'),
('Figma UX/UI Design', '2026-02-18', NULL),
('Full-Stack Web Boot Camp', NULL, NULL),
('Corporate Finance 101', '2023-08-09', '2024-06-30'),
('Digital Copywriting', NULL, NULL);

INSERT INTO students (teacher_no, course_no, first_name, last_name, email, birth_date) VALUES
(1, 1, 'Brian', 'Martinez', 'brian.martinez@gmail.com', '1999-02-14'),
(7, 5, 'David', 'Smith', 'd.smith91@gmail.com', NULL),
(7, 7, 'Charlene', 'Jones', 'charlene.jones.pro@gmail.com', '1992-10-14'),
(6, 1, 'Frederick', 'Davis', NULL, NULL),
(1, 1, 'Timothy', 'Parker', 'timothy.parker.dev@gmail.com', '1995-02-03'),
(1, 1, 'Joseph', 'Crawford', NULL, NULL),
(7, 4, 'Patricia', 'Stokes', 'patricia.stokes@gmail.com', '2005-01-19'),
(5, 6, 'Laura', 'Thompson', 'laura.thompson.design@gmail.com', NULL),
(7, 6, 'Samantha', 'Bennett', 'samantha.bennett@gmail.com', '2001-05-22'),
(5, 3, 'Michael', 'Mason', NULL, '2007-04-15');

COMMIT;


/* ----------------------------------------------------------------------------
   TASK 3: Instructor Workload Distribution Report
   Business Question: How many students has each active instructor mentored?
   SQL Techniques: INNER JOIN, COUNT Aggregation, GROUP BY
---------------------------------------------------------------------------- */
SELECT t.teacher_no,
       COUNT(s.student_no) AS total_students
FROM course_management.teachers t
INNER JOIN course_management.students s
    ON t.teacher_no = s.teacher_no
GROUP BY t.teacher_no
ORDER BY t.teacher_no;

/* Result Preview:
+------------+----------------+
| teacher_no | total_students |
+------------+----------------+
|          1 |             27 |
|          5 |             14 |
|          6 |              7 |
|          7 |             40 |
+------------+----------------+

	Key Insight: Student distribution across instructors is uneven (ranging from 1 to 4 students per mentor), indicating an opportunity to balance teaching capacity.
    
*/


/* ----------------------------------------------------------------------------
   TASK 4 & 5: Data Quality Audit — Duplicate Record Simulation & Detection
   Business Question: How can we identify duplicate student enrollment records 
   (matching personal and course attributes) and aggregate their conflicting IDs?
   SQL Techniques: INSERT INTO ... SELECT, GROUP BY, HAVING COUNT(*) > 1, GROUP_CONCAT
---------------------------------------------------------------------------- */
-- Simulate duplicate ingestion
INSERT INTO students (teacher_no, course_no, first_name, last_name, email, birth_date) 
SELECT teacher_no, 
       course_no, 
       first_name, 
       last_name, 
       email, 
       birth_date
FROM course_management.students
LIMIT 3;

-- Detect duplicates and list conflicting primary keys
SELECT GROUP_CONCAT(student_no) AS duplicate_ids, 
       teacher_no,
       course_no,
       first_name,
       last_name,
       email,
       birth_date,
       COUNT(student_no) AS duplicate_count
FROM course_management.students
GROUP BY teacher_no,
         course_no,
         first_name,
         last_name,
         email,
         birth_date
HAVING COUNT(*) > 1;

/* Result Preview:
+------------------------------+------------+-----------+------------+-----------+------------------------------+------------+-----------------+
| duplicate_ids                | teacher_no | course_no | first_name | last_name | email                        | birth_date | duplicate_count |
+------------------------------+------------+-----------+------------+-----------+------------------------------+------------+-----------------+
| 45,84,19,6,71,58,32          |          1 |         1 | Joseph     | Crawford  |          ...                 | NULL       |               7 |
| 5,57,44,18,31,83,70          |          1 |         1 | Timothy    | Parker    | timothy.parker.dev@gmail.com | 1995-02-03 |               7 |
| 75,10,23,62,36,49,88         |          5 |         3 | Michael    | Mason     | NULL                         | 2007-04-15 |               7 |
|       .....                  |     ...    |    ...    |     ...    |   ...     |          ...                 |    ...     |        ...      |
+------------------------------+------------+-----------+------------+-----------+------------------------------+------------+-----------------+

	Key Insight: Grouping by natural business keys (name, email, course, instructor) with HAVING COUNT(*) > 1 reliably isolates duplicate enrollments 
    and aggregates conflicting primary keys for safe cleanup.

*/