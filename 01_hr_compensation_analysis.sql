/* ============================================================================
   PROJECT: HR & Compensation Analytics (MySQL `employees` Database)
   AUTHOR: Nataliia Novikova
   DESCRIPTION: Analytical SQL queries addressing payroll trends, departmental 
                salary benchmarks, headcount distribution, compensation anomalies, 
                and leadership succession.
============================================================================ */

/* ----------------------------------------------------------------------------
   TASK 1: Historical Payroll Dynamics (Pre-2005 Trend)
   Business Question: How did the company's average employee salary evolve 
   year-over-year up to 2005?
   SQL Techniques: Date extraction (YEAR), Aggregation (AVG, ROUND), Filtering
---------------------------------------------------------------------------- */
SELECT YEAR(from_date) AS Years,
       ROUND(AVG(salary), 2) AS AvgSal
FROM employees.salaries
WHERE from_date <= '2005-12-31'
GROUP BY YEAR(from_date)
ORDER BY Years ASC;

/* Result Preview (Sample Output):
+-------+----------+
| Years | AvgSal   |
+-------+----------+
|  1985 | 53182.36 |
|  1986 | 54084.78 |
|  1987 | 54959.63 |
|  1988 | 55862.45 |
|  ...  | ...      |
+-------+----------+

	Key Insight: Average company compensation grew steadily year-over-year from 1985 through 2002 (the final active contract year in the dataset), 
	reflecting systematic annual salary adjustments.
    
*/

/* ----------------------------------------------------------------------------
   TASK 2: Current Departmental Salary Benchmarks
   Business Question: What is the current average salary across each department 
   based on active employee assignments and active contracts?
   SQL Techniques: Temporary Tables, CTEs, INNER JOIN, Date Range Filtering
   Note: Creates `temp_dept_avg` for reuse in Task 6 anomaly detection.
---------------------------------------------------------------------------- */
CREATE TEMPORARY TABLE IF NOT EXISTS temp_dept_avg AS
    WITH cte_sal AS (
        SELECT * 
        FROM employees.salaries
        WHERE CURDATE() BETWEEN from_date AND to_date
    ),
    cte_dept AS (
        SELECT *
        FROM employees.dept_emp
        WHERE CURDATE() BETWEEN from_date AND to_date
    )
    SELECT cd.dept_no AS Dept_no,
           ROUND(AVG(cs.salary), 2) AS AvgSal
    FROM cte_dept cd
    INNER JOIN cte_sal cs
        ON cd.emp_no = cs.emp_no
    GROUP BY cd.dept_no
    ORDER BY Dept_no ASC;

SELECT * FROM temp_dept_avg;
/* Result Preview (Sample Output):
+---------+----------+
| Dept_no | AvgSal   |
+---------+----------+
| d001    | 80058.85 |
| d002    | 78559.94 |
| ...     | ...      |
+---------+----------+

	Key Insight: Significant compensation disparity exists across business units — Sales (d007) and Marketing (d001) lead in average active pay, 
    while Human Resources (d003) and Production (d004) maintain lower cost-per-head benchmarks.
    
*/

/* ----------------------------------------------------------------------------
   TASK 3: Cross-Departmental Salary Matrix (Pivot Table by Year)
   Business Question: How do average salaries compare across all 9 departments 
   on an annual basis?
   SQL Techniques: CTE, Conditional Aggregation (Pivot using SUM + IF), JOIN
---------------------------------------------------------------------------- */
WITH cte_raw_data AS (
    SELECT YEAR(sal.from_date) AS Years,
           demp.dept_no AS Dept_no,
           ROUND(AVG(sal.salary), 2) AS AvgSal
    FROM employees.dept_emp demp
    INNER JOIN employees.salaries sal
        ON demp.emp_no = sal.emp_no
    GROUP BY YEAR(sal.from_date), demp.dept_no
)
SELECT Years,
       SUM(IF(Dept_no = 'd001', AvgSal, NULL)) AS d001,
       SUM(IF(Dept_no = 'd002', AvgSal, NULL)) AS d002,
       SUM(IF(Dept_no = 'd003', AvgSal, NULL)) AS d003,
       SUM(IF(Dept_no = 'd004', AvgSal, NULL)) AS d004,
       SUM(IF(Dept_no = 'd005', AvgSal, NULL)) AS d005, 
       SUM(IF(Dept_no = 'd006', AvgSal, NULL)) AS d006, 
       SUM(IF(Dept_no = 'd007', AvgSal, NULL)) AS d007, 
       SUM(IF(Dept_no = 'd008', AvgSal, NULL)) AS d008, 
       SUM(IF(Dept_no = 'd009', AvgSal, NULL)) AS d009
FROM cte_raw_data
GROUP BY Years
ORDER BY Years ASC;
/* Result Preview (Sample Output):
+-------+----------+----------+-----+
| Years | d001     | d002     | ... |
+-------+----------+----------+-----+
|  1985 | 61614.57 | 60285.39 | ... |
|  1986 | 62379.13 | 61078.81 | ... |
|  1987 | 63151.05 | 61838.28 | ... |
|  ...  |    ...   |    ...   | ... |
+-------+----------+----------+-----+
	
    Key Insight: The pivot matrix confirms that departmental pay gaps remained structurally consistent over time rather than resulting from one-off budget spikes.

*/


/* ----------------------------------------------------------------------------
   TASK 4: High-Capacity Operational Units (Headcount > 15,000)
   Business Question: Which departments currently employ more than 15,000 active 
   staff members and require scaled HR support?
   SQL Techniques: GROUP BY, HAVING Clause, Active Record Filtering
---------------------------------------------------------------------------- */
SELECT dept_no
FROM employees.dept_emp
WHERE CURDATE() BETWEEN from_date AND to_date
GROUP BY dept_no
HAVING COUNT(emp_no) > 15000;

/* Result Preview (Sample Output):
+---------+
| dept_no |
+---------+
| d004    |
| d005    |
| d007    |
| d008    |
| d009    |
+---------+

	Key Insight: Development (d005), Production (d004), and Sales (d007) each exceed 15,000 active employees, 
    representing the core operational workforce and primary HR administrative load.
    
*/

/* ----------------------------------------------------------------------------
   TASK 5: Longest-Tenured Active Department Manager
   Business Question: Who is the longest-serving active manager in the company, 
   and what are their employee ID, department, and hire date?
   SQL Techniques: CTE, MIN() Subquery Logic, INNER JOIN (Tie-safe approach)
---------------------------------------------------------------------------- */
WITH cte_min_hire AS (
    SELECT MIN(e.hire_date) AS min_hire_date
    FROM employees.dept_manager dm
    INNER JOIN employees.employees e 
        ON dm.emp_no = e.emp_no
    WHERE CURDATE() BETWEEN dm.from_date AND dm.to_date
)
SELECT e.emp_no,
       dm.dept_no,
       e.hire_date,
       e.last_name
FROM employees.dept_manager dm
INNER JOIN employees.employees e 
    ON dm.emp_no = e.emp_no
INNER JOIN cte_min_hire mh
    ON e.hire_date = mh.min_hire_date
WHERE CURDATE() BETWEEN dm.from_date AND dm.to_date;

/* Result Preview (Sample Output):
+--------+---------+------------+-----------+
| emp_no | dept_no | hire_date  | last_name |
+--------+---------+------------+-----------+
| 110114 | d002    | 1985-01-14 | Legleitner|
+--------+---------+------------+-----------+

	Key Insight: Identifying the earliest-hired active manager highlights institutional leadership retention 
    and flags key executive roles for upcoming succession planning.
    
*/

/* ----------------------------------------------------------------------------
   TASK 6: Top 10 Compensation Outliers vs. Departmental Average
   Business Question: Which 10 active employees have the largest absolute salary 
   deviation from their respective department's current average?
   SQL Techniques: Temporary Table Join, Math Functions (ABS), Ranking/LIMIT
---------------------------------------------------------------------------- */
WITH cte_diff_sal AS (
    SELECT de.emp_no,
           sal.salary,
           tda.AvgSal,
           ABS(sal.salary - tda.AvgSal) AS Diff
    FROM employees.dept_emp de
    INNER JOIN employees.salaries sal
        ON de.emp_no = sal.emp_no
        AND CURDATE() BETWEEN sal.from_date AND sal.to_date
    INNER JOIN temp_dept_avg tda
        ON de.dept_no = tda.dept_no
    WHERE CURDATE() BETWEEN de.from_date AND de.to_date
    ORDER BY Diff DESC
    LIMIT 10
)
SELECT emp_no
FROM cte_diff_sal;

DROP TEMPORARY TABLE IF EXISTS temp_dept_avg;
/* Result Preview (Sample Output):
+---------+
| emp_no  |
+---------+
| 421835  |
| 18006   |
| 13386   |
| ...     |
+---------+

	Key Insight: Flagging extreme deviations from departmental averages helps HR audit executive compensation packages, 
    special retention bonuses, or potential payroll anomalies.
    
*/

/* ----------------------------------------------------------------------------
   TASK 7: Leadership Succession Audit (2nd Manager per Department)
   Business Question: Who was the second appointed manager in each department's 
   history, and how long after their initial hire did they take the role?
   SQL Techniques: Window Functions (ROW_NUMBER() OVER PARTITION BY), String Concat
---------------------------------------------------------------------------- */
WITH cte_rank_manager AS (
    SELECT dm.emp_no,
           dm.dept_no,
           CONCAT(e.first_name, ' ', e.last_name) AS fullname,
           e.hire_date,
           dm.from_date,
           ROW_NUMBER() OVER (PARTITION BY dm.dept_no ORDER BY dm.from_date) AS rown
    FROM employees.dept_manager dm
    INNER JOIN employees.employees e 
        ON dm.emp_no = e.emp_no
)
SELECT dept_no,
       fullname,
       hire_date,
       from_date
FROM cte_rank_manager
WHERE rown = 2;

/* Result Preview (Sample Output):
+---------+------------------+------------+------------+
| dept_no | fullname         | hire_date  | from_date  |
+---------+------------------+------------+------------+
| d001    | Vishwani Minakawa| 1985-04-12 | 1991-10-01 |
| d002    | Isamu Legleitner | 1985-01-14 | 1989-12-17 |
| d003    | Karsten Sigstam  | 1985-08-04 | 1992-03-21 |
| ...     | ...              | ...        | ...        |
+---------+------------------+------------+------------+

	Key Insight: Tracking the transition to the second manager per department reveals internal promotion timelines 
    (comparing original hire_date vs. management appointment from_date).
    
*/