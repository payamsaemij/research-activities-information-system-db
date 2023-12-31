-- =========================
-- The project asked queries
-- =========================


-- ==================
-- Institutes Reports
-- ==================
SET @test_institute_id = 16;

-- First Query:
-- information of current and previous researchers (all together)
SELECT
	p.*
FROM persons p
INNER JOIN contracts c
	ON p.id = c.person_id
INNER JOIN research_activities ra
	ON c.research_activity_id = ra.id
WHERE ra.institute_id = @test_institute_id;


-- information of current and previous researchers (labeled)
-- NOTE: It can return duplicate person with different statues, need to be fixed
SELECT
	p.*,
    'currently in contract' AS status
FROM persons p
INNER JOIN contracts c
	ON p.id = c.person_id
INNER JOIN research_activities ra
	ON c.research_activity_id = ra.id
WHERE
	ra.institute_id = @test_institute_id AND
    (c.end_date IS NULL OR c.end_date >= CURDATE())
UNION
SELECT
	p.*,
    'previous researcher' AS status
FROM persons p
INNER JOIN contracts c
	ON p.id = c.person_id
INNER JOIN research_activities ra
	ON c.research_activity_id = ra.id
WHERE
	ra.institute_id = @test_institute_id AND
    (c.end_date < CURDATE());
    
-- Second Query:
-- Financial records of an institute (salary payments in research activities)
SELECT
	*
FROM research_activity_salary_payments
WHERE research_activity_id IN (
	SELECT id
    FROM research_activities
    WHERE institute_id = @test_institute_id
);

-- Financial records of an institute (financial supports for research activities)
SELECT 
	rafs.id,
    rafs.institute_id,
    rafs.research_activity_id,
    fst.title AS support_type,
    rafs.amount,
    rafs.paid_at
FROM research_activity_financial_supports rafs
INNER JOIN financial_support_types fst
	ON rafs.type_id = fst.id
WHERE institute_id = @test_institute_id;

-- Total financial records of an institute (both supports and salary payments)
SELECT
	sum(amount),
    'Salary' AS type
FROM research_activity_salary_payments
WHERE research_activity_id IN (
	SELECT id
    FROM research_activities
    WHERE institute_id = @test_institute_id
)
UNION
SELECT
    sum(rafs.amount),
    fst.title AS type
FROM research_activity_financial_supports rafs
INNER JOIN financial_support_types fst
	ON rafs.type_id = fst.id
WHERE institute_id = @test_institute_id
GROUP BY type;

-- Third Query:
-- Institute preferred research areas
SELECT 
	iwa.institute_id,
    i.name,
    ra.title AS research_area
FROM institute_work_areas iwa
INNER JOIN research_areas ra
	ON iwa.area_id = ra.id
INNER JOIN institutes i
	ON iwa.institute_id = i.id;
    
-- Institute activities research areas
SELECT
	rarea.title AS research_area
FROM research_activities ra
INNER JOIN research_activity_areas raa
	ON ra.id = raa.research_activity_id
INNER JOIN research_areas rarea
	ON raa.research_area_id = rarea.id
WHERE ra.institute_id = @test_institute_id;

-- Fourth Query:
-- Institute research activities
-- (to have the research title (like paper name) this result must be joined with each table seperately)
SELECT 
	ra.id,
    rat.title as type,
    ra.content_id,
    concat(p.first_name, ' ', p.last_name) AS officer_researcher,
    ra.is_international,
    ra.start_date,
    ra.end_date
FROM research_activities ra
INNER JOIN research_activity_types rat
	ON ra.type_id = rat.id
INNER JOIN persons p
	ON ra.officer_researcher_id = p.id
WHERE institute_id = @test_institute_id;

-- ===================
-- Researchers Reports
-- ===================
SET @test_researcher_id = 1;
SET @test_start_period = '2013-01-01';
SET @test_end_period = '2023-06-06';

-- First Query:
-- Information of all researchers
SELECT DISTINCT p.*
FROM persons p
INNER JOIN contracts c
	ON p.id = c.person_id;

-- Second Query:
-- History of a researcher's research activities in a given period
SELECT
	ra.id,
    i.name AS institute,
    rat.title AS type,
    ra.content_id,
    ra.is_international,
    c.role,
    c.duties,
    c.salary,
    c.start_date,
    c.end_date
FROM research_activities ra
INNER JOIN contracts c
	ON ra.id = c.research_activity_id
INNER JOIN research_activity_types rat
	ON ra.type_id = rat.id
INNER JOIN institutes i
	ON ra.institute_id = i.id
WHERE c.person_id = @test_researcher_id AND (
	c.start_date BETWEEN @test_start_period AND @test_end_period
    OR c.end_date BETWEEN @test_start_period AND @test_end_period
    OR @test_start_period BETWEEN c.start_date AND c.end_date
);

-- Second Query:
-- Salary payment records of researcher
SELECT *
FROM research_activity_salary_payments
WHERE researcher_id = @test_researcher_id;

-- Sum of paid salaries in a given period
SELECT
	count(*) AS number_of_payments,
	sum(amount) AS total_amount
FROM research_activity_salary_payments
WHERE researcher_id = @test_researcher_id
	  AND paid_at BETWEEN @test_start_period AND @test_end_period;

-- Sum of paid salaries grouped by date
SELECT
	YEAR(paid_at),
	count(*) AS number_of_payments,
	sum(amount) AS total_amount
FROM research_activity_salary_payments
WHERE researcher_id = @test_researcher_id
GROUP BY YEAR(paid_at) WITH ROLLUP;

-- ======================
-- Research Teams Reports
-- ======================
SET @test_researcher_id = 1;

-- First Query:
-- Researchers that have mututal research activity with a specific researcher and their activity information
SELECT DISTINCT
	c.person_id,
    CONCAT(p.first_name, ' ', p.last_name) AS researcher_name,
	c.research_activity_id,
	rat.title AS type,
	ra.content_id,
    i.name AS institute
FROM contracts c
INNER JOIN research_activities ra
	ON c.research_activity_id = ra.id
INNER JOIN research_activity_types rat
	ON ra.type_id = rat.id
INNER JOIN institutes i
	ON ra.institute_id = i.id
INNER JOIN persons p
	ON c.person_id = p.id
WHERE c.research_activity_id IN (
	SELECT research_activity_id
	FROM contracts
	WHERE person_id = @test_researcher_id
) AND person_id != @test_researcher_id;

-- Second Query:
-- Researchers that have related research activity with a specific researcher
-- and their activity information
SELECT DISTINCT
	c.person_id,
    CONCAT(p.first_name, ' ', p.last_name) AS researcher_name,
	rarea.title AS research_area,
	rat.title AS type,
	ra.content_id AS content_id
FROM contracts c
INNER JOIN research_activity_areas raa
	ON c.research_activity_id = raa.research_activity_id
INNER JOIN research_activities ra
	ON c.research_activity_id = ra.id
INNER JOIN research_activity_types rat
	ON ra.type_id = rat.id
INNER JOIN research_areas rarea
	ON raa.research_area_id = rarea.id
INNER JOIN institutes i
	ON ra.institute_id = i.id
INNER JOIN persons p
	ON c.person_id = p.id
WHERE raa.research_area_id IN (
	SELECT DISTINCT
		raa.research_area_id
	FROM contracts c
	INNER JOIN research_activity_areas raa
		ON raa.research_activity_id = c.research_activity_id
	WHERE person_id = @test_researcher_id
) AND person_id != @test_researcher_id;

-- Researchers that have related research activity with a specific researcher
-- and their activity information, grouped
SELECT DISTINCT
	c.person_id,
    CONCAT(p.first_name, ' ', p.last_name) AS researcher_name,
	GROUP_CONCAT(rarea.title) AS research_areas,
	GROUP_CONCAT(c.research_activity_id) AS research_activity_ids,
	rat.title AS type,
	GROUP_CONCAT(ra.content_id) AS content_ids
FROM contracts c
INNER JOIN research_activity_areas raa
	ON c.research_activity_id = raa.research_activity_id
INNER JOIN research_activities ra
	ON c.research_activity_id = ra.id
INNER JOIN research_activity_types rat
	ON ra.type_id = rat.id
INNER JOIN research_areas rarea
	ON raa.research_area_id = rarea.id
INNER JOIN institutes i
	ON ra.institute_id = i.id
INNER JOIN persons p
	ON c.person_id = p.id
WHERE raa.research_area_id IN (
	SELECT DISTINCT
		raa.research_area_id
	FROM contracts c
	INNER JOIN research_activity_areas raa
		ON raa.research_activity_id = c.research_activity_id
	WHERE person_id = @test_researcher_id
) AND person_id != @test_researcher_id
GROUP BY c.person_id, researcher_name, type;

-- ===========================
-- Research Activities Reports
-- ===========================
SET @test_research_activity_id=1675;
SET @test_start_period='2019-01-01';
SET @test_end_period='2022-01-01';

-- First Query:
-- Information of researchers who've been working in a specific period of date
SELECT DISTINCT p.*
FROM persons p
INNER JOIN contracts c
	ON c.person_id = p.id
WHERE (
	c.start_date BETWEEN @test_start_period AND @test_end_period
    OR c.end_date BETWEEN @test_start_period AND @test_end_period
    OR @test_start_period BETWEEN c.start_date AND c.end_date
);

-- Second Query:
-- Total financial records and financial records grouped by researcher
SELECT 
	COALESCE(rasp.researcher_id, 'Total') as researcher_id,
    CONCAT(p.first_name, ' ', p.last_name) AS researcher,
	SUM(rasp.amount) AS total_salary_paid
FROM research_activity_salary_payments rasp
INNER JOIN persons p
	ON rasp.researcher_id = p.id
WHERE rasp.research_activity_id = @test_research_activity_id
GROUP BY researcher_id, researcher WITH ROLLUP
HAVING GROUPING(researcher)=0 OR researcher_id IS NULL;