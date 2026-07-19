const fs = require("fs");
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, LevelFormat,
  HeadingLevel, BorderStyle, WidthType, ShadingType,
  PageNumber, PageBreak, TabStopType, TabStopPosition
} = require("docx");

// Common styles
const TNR = "Times New Roman";
const sz24 = 24; // 12pt
const sz28 = 28; // 14pt

const border = { style: BorderStyle.SINGLE, size: 1, color: "000000" };
const borders = { top: border, bottom: border, left: border, right: border };
const cellMargins = { top: 60, bottom: 60, left: 100, right: 100 };

function p(text, opts = {}) {
  const runs = [];
  if (typeof text === "string") {
    runs.push(new TextRun({
      text,
      font: TNR,
      size: opts.size || sz24,
      bold: opts.bold || false,
      italics: opts.italics || false,
    }));
  } else if (Array.isArray(text)) {
    text.forEach(t => {
      if (typeof t === "string") {
        runs.push(new TextRun({ text: t, font: TNR, size: opts.size || sz24 }));
      } else {
        runs.push(new TextRun({ font: TNR, size: opts.size || sz24, ...t }));
      }
    });
  }
  return new Paragraph({
    children: runs,
    spacing: { after: opts.after !== undefined ? opts.after : 200, line: opts.line || 480 },
    alignment: opts.align || AlignmentType.JUSTIFIED,
    indent: opts.indent ? { firstLine: 720 } : undefined,
    heading: opts.heading,
    pageBreakBefore: opts.pageBreak || false,
  });
}

function heading1(text, pageBreak = true) {
  return new Paragraph({
    children: [new TextRun({ text, font: TNR, size: 32, bold: true })],
    spacing: { before: 240, after: 240, line: 480 },
    alignment: AlignmentType.LEFT,
    pageBreakBefore: pageBreak,
  });
}

function heading2(text) {
  return new Paragraph({
    children: [new TextRun({ text, font: TNR, size: sz28, bold: true })],
    spacing: { before: 200, after: 200, line: 480 },
    alignment: AlignmentType.LEFT,
  });
}

function heading3(text) {
  return new Paragraph({
    children: [new TextRun({ text, font: TNR, size: sz24, bold: true })],
    spacing: { before: 160, after: 160, line: 480 },
    alignment: AlignmentType.LEFT,
  });
}

function tableCell(text, opts = {}) {
  return new TableCell({
    borders,
    width: opts.width ? { size: opts.width, type: WidthType.DXA } : undefined,
    margins: cellMargins,
    shading: opts.shading ? { fill: opts.shading, type: ShadingType.CLEAR } : undefined,
    children: [new Paragraph({
      children: [new TextRun({
        text,
        font: TNR,
        size: opts.size || 20,
        bold: opts.bold || false,
      })],
      alignment: opts.align || AlignmentType.LEFT,
      spacing: { after: 0, line: 276 },
    })],
  });
}

// ===== BUILD DOCUMENT =====
const doc = new Document({
  styles: {
    default: {
      document: {
        run: { font: TNR, size: sz24 },
        paragraph: { spacing: { line: 480 } },
      },
    },
  },
  sections: [
    // ===== TITLE PAGE =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      children: [
        p("", { after: 1200 }),
        p("Improving Security and Performance of Financial RESTful APIs Using ChatGPT in ASP.NET Core", {
          bold: true, size: 52, align: AlignmentType.CENTER, after: 600, line: 360,
        }),
        p("", { after: 400 }),
        p("By", { size: sz28, align: AlignmentType.CENTER, after: 400 }),
        p("ZAW YE HTUT KO", { bold: true, size: 32, align: AlignmentType.CENTER, after: 600 }),
        p("Master Thesis Proposal", { bold: true, size: 34, align: AlignmentType.CENTER, after: 400, line: 360 }),
        p("", { after: 200 }),
        p("Submitted in Partial Fulfilment of the Requirements for the Degree of Master of Science in Information Technology, Assumption University", {
          bold: true, size: 34, align: AlignmentType.CENTER, after: 400, line: 360,
        }),
        p("", { after: 200 }),
        p("March 2026", { bold: true, size: sz28, align: AlignmentType.CENTER, after: 400 }),
        p("Vincent Mary School of Engineering, Science and Technology", {
          bold: true, size: sz28, align: AlignmentType.CENTER, after: 200,
        }),
      ],
    },
    // ===== APPROVAL PAGE =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      children: [
        p("Thesis Proposal Approval", { bold: true, size: 32, align: AlignmentType.CENTER, after: 400 }),
        p("", { after: 200 }),
        p([{ text: "Thesis Title: ", bold: true }, { text: "Improving Security and Performance of Financial RESTful APIs Using ChatGPT in ASP.NET Core" }], { after: 200 }),
        p([{ text: "By: ", bold: true }, { text: "ZAW YE HTUT KO" }], { after: 200 }),
        p([{ text: "Thesis Advisor: ", bold: true }, { text: "ASST PROF. DR. DARUN KESRARAT" }], { after: 200 }),
        p([{ text: "Academic Year: ", bold: true }, { text: "2/2025" }], { after: 200 }),
        p("", { after: 200 }),
        p("The Vincent Mary School of Engineering, Science and Technology of Assumption University has approved this proposal as the partial fulfilment of the requirements for the degree of Master of Science in Information Technology.", { after: 400 }),
        p("Approval Committee:", { bold: true, after: 400 }),
      ],
    },
    // ===== ABSTRACT =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      children: [
        heading1("Abstract", false),
        p("In today\u2019s digital landscape, RESTful APIs have become indispensable for enabling communication across diverse software systems, from e-commerce to financial applications. RESTful APIs, which follow the Representational State Transfer architectural style, provide a standardized approach for client-server communication using standard HTTP methods such as GET, POST, PUT, and DELETE (Zhang et al., 2023; Efuntade & Efuntade, 2023). Despite their widespread adoption, securing and optimizing these APIs remains a complex challenge, with common vulnerabilities such as SQL injection, Cross-Site Scripting (XSS), and broken access control exposing them to significant threats (Flores & Monreal, 2024).", { indent: true }),
        p("This thesis explores the potential of ChatGPT (ChatGPT 5.4 Codex, OpenAI, 2025\u20132026), a large language model developed by OpenAI, to assist in improving the security, performance, and maintainability of ASP.NET Core 8.0 RESTful APIs. Using a financial accounting API as the study subject\u2014a complex project with endpoints for journal entries, chart of accounts, financial reporting, user authentication, and audit logging\u2014this study investigates the impact of ChatGPT\u2019s code recommendations on key metrics, including code security, performance, and code quality.", { indent: true }),
        p("Key tools employed include SonarQube Community Edition (v24.12) for static code analysis, Apache JMeter 5.5 for performance testing, and OWASP ZAP (stable release, 2024) for vulnerability assessment. The study follows a branch-based testing methodology: baseline metrics are captured on the baseline-v0.1 branch, then ChatGPT-guided fixes are applied on separate branches (baseline-sonarqube-v1, baseline-zap-v1, and baseline-jmeter-v1), and re-testing is performed to measure improvements. Preliminary results demonstrate that ChatGPT\u2019s recommendations achieved a 100% reduction in medium and low severity security alerts, 73\u201394% reduction in p95 response times, and complete elimination of all code smells, providing valuable insights into the role of AI-driven assistance in modern software development (Fajkovic & Rundberg, 2023; Yeti\u015Ftiren et al., 2023).", { indent: true }),
      ],
    },
    // ===== TABLE OF CONTENTS (placeholder) =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      children: [
        heading1("Table of Contents", false),
        p("(Table of Contents \u2014 to be generated in Word after opening the document)", { align: AlignmentType.CENTER }),
      ],
    },
    // ===== LIST OF ACRONYMS =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      children: [
        heading1("List of Acronyms", false),
        ...[
          ["AI", "Artificial Intelligence"],
          ["API", "Application Programming Interface"],
          ["ASP.NET", "Active Server Pages .NET"],
          ["CPU", "Central Processing Unit"],
          ["CSRF", "Cross-Site Request Forgery"],
          ["CWE", "Common Weakness Enumeration"],
          ["GPT", "Generative Pre-trained Transformer"],
          ["HTTP", "Hypertext Transfer Protocol"],
          ["IDE", "Integrated Development Environment"],
          ["JMeter", "Java Meter (Apache JMeter)"],
          ["JWT", "JSON Web Token"],
          ["LLM", "Large Language Model"],
          ["NLP", "Natural Language Processing"],
          ["OWASP", "Open Web Application Security Project"],
          ["RBAC", "Role-Based Access Control"],
          ["REST", "Representational State Transfer"],
          ["SQL", "Structured Query Language"],
          ["XSS", "Cross-Site Scripting"],
          ["ZAP", "Zed Attack Proxy"],
        ].map(([abbr, full]) => p([{ text: abbr, bold: true }, { text: ` \u2014 ${full}` }], { after: 80, line: 360 })),
      ],
    },
    // ===== CHAPTER 1 - INTRODUCTION =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      headers: {
        default: new Header({
          children: [new Paragraph({
            children: [new TextRun({ text: "Improving Security and Performance of Financial RESTful APIs Using ChatGPT", font: TNR, size: 18, italics: true })],
            alignment: AlignmentType.RIGHT,
          })],
        }),
      },
      footers: {
        default: new Footer({
          children: [new Paragraph({
            children: [new TextRun({ text: "Page ", font: TNR, size: 20 }), new TextRun({ children: [PageNumber.CURRENT], font: TNR, size: 20 })],
            alignment: AlignmentType.CENTER,
          })],
        }),
      },
      children: [
        heading1("Chapter 1: Introduction", false),

        heading2("1.1 Introduction"),
        p("In the rapidly evolving field of software development, Application Programming Interfaces (APIs) have become essential components that enable communication between different software systems. An API is a set of functions and protocols that allow developers to access the features and data of software applications, extending functionalities and facilitating integration with third-party services (Efuntade & Efuntade, 2023). APIs serve as intermediaries between software systems, enabling them to communicate and share data in a standardized manner. In the financial sector, APIs have become particularly critical, as they enable the management of sensitive information such as transaction data, account balances, and user authentication across distributed systems (Efuntade & Efuntade, 2023).", { indent: true }),
        p("Among the various API architectural styles, RESTful APIs (Representational State Transfer) have gained prominence due to their scalability, simplicity, and stateless nature. RESTful APIs leverage standard HTTP methods\u2014GET for retrieving resources, POST for creating new resources, PUT for updating existing resources, and DELETE for removing resources\u2014to provide a uniform interface for client-server communication (Zhang et al., 2023). According to Zhang et al. (2023), who conducted a large-scale empirical study of 20,047 web APIs from ProgrammableWeb and APIs.guru, RESTful APIs have become the fundamental building blocks for constructing modern software applications across industries including e-commerce, finance, and healthcare.", { indent: true }),
        p("ChatGPT, developed by OpenAI, represents a significant breakthrough in artificial intelligence. Built on the Generative Pre-trained Transformer (GPT) architecture, ChatGPT is a large language model (LLM) that has demonstrated remarkable capabilities in understanding and generating human-like text across various domains, including software development (Jain et al., 2025). The model has evolved through several versions: GPT-3.5 introduced conversational capabilities, GPT-4 brought multimodal understanding and improved reasoning, GPT-4o further optimized performance and efficiency, and the latest ChatGPT 5.4 Codex delivers state-of-the-art code generation and analysis capabilities (Jain et al., 2025). In this study, ChatGPT 5.4 Codex (OpenAI, 2025\u20132026) is used to generate code recommendations, leveraging its advanced reasoning and code-specific optimization capabilities. When applied to API development, ChatGPT can assist in generating, optimizing, and improving code for better security, performance, and maintainability (\u00D6zpolat et al., 2023; Fajkovic & Rundberg, 2023).", { indent: true }),

        heading2("1.2 Challenges in API Security and Performance"),
        p("APIs, particularly those handling sensitive financial data, are frequent targets for cyberattacks. The Open Web Application Security Project (OWASP) Top 10, which serves as the industry-standard framework for categorizing web application security risks, identifies several critical vulnerability categories that affect APIs. According to Flores and Monreal (2024), who evaluated 17 state university and college websites using OWASP ZAP, 94.12% were vulnerable to broken access control, 88.24% exhibited security misconfigurations, and 70.59% had outdated and vulnerable components. These findings underscore the pervasive nature of security vulnerabilities in web applications, including APIs.", { indent: true }),
        p("Common security risks that threaten RESTful APIs include SQL injection, where malicious SQL statements are inserted into input fields to manipulate database queries; Cross-Site Scripting (XSS), where attackers inject malicious scripts into web pages viewed by other users; and Cross-Site Request Forgery (CSRF), where unauthorized commands are transmitted from a user that the application trusts (Flores & Monreal, 2024; Szab\u00F3 & Bilicki, 2023). Szab\u00F3 and Bilicki (2023) demonstrated that GPT language models achieved an 88.76% detection success rate for CWE-653 vulnerabilities (inadequately isolated sensitive code segments), indicating the potential for AI-driven security inspection. However, they also noted that around 70% of ChatGPT-generated solutions contained security API misuse, highlighting the need for human oversight and iterative refinement of AI recommendations.", { indent: true }),
        p("Beyond security, performance optimization remains equally challenging. Financial APIs must handle high volumes of concurrent transactions while maintaining low latency and high throughput. Traditional approaches to identifying and resolving performance bottlenecks\u2014such as manual code review, profiling, and load testing\u2014are time-consuming and require significant expertise. These manual processes are particularly burdensome when dealing with complex multi-tier architectures that include API layers, business logic layers, data models, and testing frameworks. A developer must trace performance issues across multiple layers, analyze database query efficiency, evaluate caching strategies, and optimize resource utilization\u2014tasks that can take days or weeks of manual effort for a single optimization cycle.", { indent: true }),

        heading2("1.3 Problem Statement"),
        p("Securing RESTful APIs is a multifaceted challenge that involves addressing multiple layers of vulnerabilities, from user authentication and authorization to input validation and data integrity. Traditional methods of securing and optimizing APIs rely heavily on manual intervention by experienced developers, which is both time-consuming and prone to human error. A developer must manually review security scanner reports (such as those from OWASP ZAP), interpret each finding, research the appropriate fix, implement the solution, and verify that the fix does not introduce regressions\u2014a cycle that typically requires several hours per vulnerability. Similarly, performance optimization requires manual analysis of profiling data, identification of bottlenecks, implementation of optimizations such as query tuning and caching, and re-testing under various load conditions.", { indent: true }),
        p("This research explores how ChatGPT 5.4 Codex can help address these challenges by applying AI-driven recommendations to enhance the security and performance of a financial accounting RESTful API built with ASP.NET Core 8.0. The study investigates the impact of ChatGPT-generated code improvements by comparing baseline metrics against post-improvement results across three dimensions: security vulnerabilities detected by OWASP ZAP, performance metrics measured by Apache JMeter 5.5, and code quality analyzed by SonarQube Community Edition.", { indent: true }),

        heading2("1.4 Motivation Statement"),
        p("The motivation behind this research stems from the growing body of evidence suggesting that AI-assisted coding tools can significantly enhance developer productivity and code quality. Peng et al. (2023) demonstrated through a controlled experiment that developers using GitHub Copilot, an AI pair programmer powered by OpenAI\u2019s Codex model, completed tasks 55.8% faster than those in the control group. The tool particularly benefited less experienced developers, suggesting its potential for democratizing software development expertise. Similarly, Yeti\u015Ftiren et al. (2023) found that ChatGPT achieved a 65.2% correctness rate in code generation tasks evaluated using the HumanEval dataset, outperforming both GitHub Copilot (46.3%) and Amazon CodeWhisperer (31.1%).", { indent: true }),
        p("These findings motivate the exploration of ChatGPT\u2019s capabilities specifically in the context of API security and performance optimization\u2014areas where the combination of AI\u2019s pattern recognition capabilities and its training on vast codebases could provide actionable recommendations that would otherwise require extensive manual effort. Unlike general code generation tasks studied in prior literature, this research focuses on the practical application of ChatGPT for targeted, tool-specific improvements in a real-world financial API system.", { indent: true }),

        heading2("1.5 Objectives and Expected Outcomes"),
        heading3("1.5.1 Objectives"),
        p("The primary objectives of this research are as follows:", { after: 100 }),
        p("1. To evaluate the impact of ChatGPT 5.4 Codex on the security of ASP.NET Core 8.0 RESTful API projects by measuring the reduction in vulnerabilities detected by OWASP ZAP before and after applying ChatGPT\u2019s recommendations.", { after: 100 }),
        p("2. To assess the performance impacts of ChatGPT-guided code improvements through load testing with Apache JMeter 5.5, measuring response times (in milliseconds), throughput (in transactions per second), and error rates (in percentage) under concurrent user loads of 50, 100, and 500 users, as well as soak and spike test profiles.", { after: 100 }),
        p("3. To measure improvements in code quality, reliability, and maintainability using SonarQube Community Edition (v24.12), tracking metrics including code smells (count), bugs (count), vulnerabilities (count), security hotspots (count), code coverage (percentage), and duplicated lines density (percentage).", { after: 100 }),
        p("4. To demonstrate how ChatGPT can address security problems such as missing Content Security Policy headers, missing Anti-CSRF tokens, server information leakage, and improper cookie attributes in RESTful APIs through AI-generated code recommendations.", { after: 200 }),

        heading3("1.5.2 Expected Outcomes"),
        p("The expected outcomes of this research include:", { after: 100 }),
        p("1. A comprehensive analysis of the before-and-after results for the financial accounting API project following ChatGPT\u2019s code recommendations, measured in specific units: security alerts by severity level (count of High, Medium, Low, and Informational alerts), response times in milliseconds (ms) for p95 latency, throughput in transactions per second (tx/s), error rates in percentage (%), and code quality metrics by issue count and quality gate status.", { after: 100 }),
        p("2. Empirical data on improvements in code quality, including reduced bugs, vulnerabilities, and code smells as measured by SonarQube\u2019s static analysis.", { after: 100 }),
        p("3. Enhanced security measures for authentication and authorization, including proper JWT implementation, role-based access control enforcement, Content Security Policy headers, anti-CSRF tokens, and secure cookie attributes.", { after: 100 }),
        p("4. Optimized performance metrics, including faster response times measured in milliseconds and improved throughput measured in transactions per second.", { after: 200 }),

        heading2("1.6 Limitations"),
        p("The scope of this research is limited to ASP.NET Core 8.0 RESTful APIs deployed on a Windows 11 development environment with SQL Server as the database backend. Only ChatGPT 5.4 Codex (OpenAI, 2025\u20132026) will be evaluated as the AI assistance tool, excluding comparisons with other AI tools such as GitHub Copilot or Amazon CodeWhisperer. The analysis focuses on static code analysis (SonarQube), security scanning (OWASP ZAP), and performance testing (Apache JMeter), leaving out aspects related to user experience, developer productivity measurement, and deployment to production environments. The financial accounting dataset used is a simulated dataset designed for testing purposes and does not represent actual financial institution data.", { indent: true }),
      ],
    },
    // ===== CHAPTER 2 - LITERATURE REVIEW =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      headers: {
        default: new Header({
          children: [new Paragraph({
            children: [new TextRun({ text: "Chapter 2: Literature Review", font: TNR, size: 18, italics: true })],
            alignment: AlignmentType.RIGHT,
          })],
        }),
      },
      footers: {
        default: new Footer({
          children: [new Paragraph({
            children: [new TextRun({ text: "Page ", font: TNR, size: 20 }), new TextRun({ children: [PageNumber.CURRENT], font: TNR, size: 20 })],
            alignment: AlignmentType.CENTER,
          })],
        }),
      },
      children: [
        heading1("Chapter 2: Literature Review", false),
        p("This chapter reviews the existing body of literature relevant to AI-assisted code generation, RESTful API security and performance, and the application of large language models in software engineering. The literature is organized thematically, beginning with studies that evaluate AI code generation tools, followed by research on web API challenges and security assessment methodologies, and concluding with empirical evidence on AI\u2019s impact on developer productivity. Each section synthesizes key findings, identifies gaps in the literature, and establishes the theoretical foundation for this study\u2019s investigation of ChatGPT\u2019s effectiveness in improving financial RESTful APIs.", { indent: true }),

        heading2("2.1 AI-Assisted Code Generation: Capabilities and Limitations"),
        p("The emergence of large language models has transformed the landscape of software development by enabling AI-driven code generation at an unprecedented scale. Fajkovic and Rundberg (2023) conducted a comparative study of ChatGPT (built on OpenAI\u2019s GPT-3.5 and GPT-4 architecture) and GitHub Copilot (powered by OpenAI\u2019s Codex model) in the context of web development. Their design-based research methodology evaluated both tools on the task of recreating a website from wireframe specifications, assessing efficiency, accuracy, maintainability, and ease of use. The generated code was analyzed both manually through code review and using static analysis tools including SonarQube, ESLint, and Pylint. Their results revealed that while both tools could generate functional websites with minor styling discrepancies, ChatGPT was rated as more user-friendly and produced code that was slightly more consistent. However, they concluded that code-generating AI is \u201Cnot advanced enough to create systems from scratch in a time-efficient way without introducing bugs and security risks\u201D (Fajkovic & Rundberg, 2023, p. 1). This finding is directly relevant to the current study, as it suggests that AI tools are most effective when used to augment rather than replace developer expertise\u2014a principle that underlies this research\u2019s approach of using ChatGPT for targeted code recommendations rather than wholesale code generation.", { indent: true }),
        p("Building upon this foundation, S\u00E1godi et al. (2024) proposed a systematic methodology for evaluating large language models in code synthesis tasks. Their study, published in IEEE Access, compared ChatGPT and GitHub Copilot using 25 programming tasks in C++ and Java. The methodology encompassed four phases: selecting the right prompt, checking functional validity, checking technical quality through static code analysis, and human evaluation. Their key findings demonstrated that ChatGPT performed better on average, generating more correct solutions than Copilot, though both tools exhibited recurring code smells and security vulnerabilities. Notably, prompt engineering emerged as a critical factor influencing code quality\u2014a finding that informs this study\u2019s approach of carefully crafting prompts to guide ChatGPT\u2019s recommendations for security and performance improvements. S\u00E1godi et al. (2024) also highlighted the importance of combining automated static analysis with human review for comprehensive quality assessment, which aligns with this study\u2019s multi-tool evaluation strategy using SonarQube, OWASP ZAP, and Apache JMeter.", { indent: true }),

        heading2("2.2 ChatGPT in Software Development Workflows"),
        p("\u00D6zpolat et al. (2023) examined the role of artificial intelligence-based tools, specifically ChatGPT (GPT-3.5 and GPT-4), in software development processes. Published in the European Journal of Technique, their study highlighted how ChatGPT can enhance workflows across the entire software development lifecycle\u2014from requirements analysis and design to coding, testing, and maintenance. The authors found that ChatGPT was effective in automating repetitive tasks, reducing development time, and simplifying processes for non-specialist developers. However, they also raised important concerns about over-reliance on AI for critical functions, emphasizing the need for human oversight. Their critical analysis underscored the risks of over-dependency on AI, particularly in security-sensitive contexts where incorrect AI-generated code could introduce new vulnerabilities. This finding directly supports the current study\u2019s methodology of applying ChatGPT recommendations iteratively and verifying improvements through independent testing tools.", { indent: true }),
        p("Chen et al. (2023) further explored the educational and explanatory capabilities of ChatGPT through GPTutor, a Visual Studio Code extension that leverages the OpenAI ChatGPT API (specifically GPT-3.5) to provide detailed, context-aware explanations of source code. Unlike vanilla ChatGPT or GitHub Copilot, GPTutor integrates with the Visual Studio Code API to comprehensively analyze code by referencing relevant source files, enabling it to provide more accurate and concise explanations. Their preliminary evaluation demonstrated that GPTutor delivered the most concise and accurate explanations compared to baseline ChatGPT and GitHub Copilot. The study is relevant because it demonstrates how ChatGPT can be integrated into development environments to help developers understand existing codebases\u2014a capability that extends to understanding security vulnerabilities and performance bottlenecks in code, which is central to this research.", { indent: true }),

        heading2("2.3 The Evolution of GPT Models for Programming"),
        p("Jain et al. (2025) conducted a comparative study on the evolution of ChatGPT for programming, published in Engineering Research Express. Their research systematically evaluated three GPT model versions\u2014GPT-3.5, GPT-4, and GPT-4o\u2014across 15 LeetCode algorithmic problems in three programming languages: Python, Java, and C++. Each solution was generated and executed 10 times, with runtime and memory usage measured and analyzed using two-way ANOVA and post hoc Tukey\u2019s HSD tests. The findings revealed that while programming language choice had a significant effect on memory and runtime efficiency (C++ outperforming Python and Java), there were no statistically significant differences in performance between GPT-3.5, GPT-4, and GPT-4o across most tasks. Python was found to be significantly slower and more memory-intensive compared to C++ and Java.", { indent: true }),
        p("This study is particularly relevant to the current research because it provides empirical evidence on the performance characteristics of different GPT model versions. The finding that newer GPT models do not always translate to measurably better code efficiency underscores the importance of evaluating ChatGPT\u2019s recommendations through independent testing rather than assuming superior model versions produce superior code. In this thesis, ChatGPT 5.4 Codex is used to generate code recommendations, and the effectiveness of these recommendations is validated independently through SonarQube, OWASP ZAP, and Apache JMeter testing\u2014aligning with Jain et al.\u2019s (2025) emphasis on empirical evaluation over model-version assumptions.", { indent: true }),

        heading2("2.4 Web API Security, Features, and Challenges"),
        p("Zhang et al. (2023) conducted a large-scale empirical study of 20,047 web APIs published at two popular registries\u2014ProgrammableWeb and APIs.guru\u2014to investigate API usage patterns, common issues, and user expectations. Their methodology involved extracting 1,885 randomly sampled questions from Stack Overflow related to these APIs, identifying 24 distinct web API issue types (including authorization errors, performance problems, and documentation gaps). They also conducted a user survey with 191 industry professionals and GitHub developers, extracting 14 important features for API adoption (such as well-organized documentation) and 11 categories of user expectations. Key findings showed that security issues and limited functionality were among the most common concerns reported by API users, and that well-organized documentation is critical for API adoption.", { indent: true }),
        p("The significance of this study for the current research is twofold. First, it establishes the empirical basis for the types of issues that RESTful APIs commonly face, validating the focus on security and performance as primary evaluation dimensions. Second, it highlights the gap in machine-learning-driven API enhancements\u2014a gap that the current study aims to address by investigating how ChatGPT can generate actionable recommendations for improving API security and performance.", { indent: true }),
        p("Complementing the API-centric perspective, Efuntade and Efuntade (2023) examined the intersection of APIs and accounting information systems (AIS) in their study published in the Journal of Accounting and Financial Management. They explored how APIs enable the management of web-based accounting information systems, with particular attention to the security of transaction processing systems, general ledgers, and financial reporting systems. Their exploratory research highlighted that APIs serve as critical intermediaries between financial data provider systems and external applications, making their security paramount. The study noted that API banking is becoming \u201Ca critical step in helping customers and business partners innovate for new technologies\u201D (Efuntade & Efuntade, 2023). This work provides direct domain-specific justification for the current study\u2019s focus on financial accounting APIs, demonstrating that the intersection of API security and financial data management is an active area of concern in both industry and academia.", { indent: true }),

        heading2("2.5 Security Vulnerability Assessment Using OWASP"),
        p("Flores and Monreal (2024) conducted a systematic evaluation of common security vulnerabilities in state university and college websites in the Philippines, utilizing the OWASP Zed Attack Proxy (ZAP) as their primary scanning tool. Their study evaluated 17 institutional websites against the OWASP Top 10 2021 security risk categories. The results were alarming: 94.12% of websites were vulnerable to broken access control (A01:2021), 88.24% exhibited security misconfigurations (A05:2021), 70.59% had outdated and vulnerable components (A06:2021), 40.06% demonstrated insecure design (A04:2021), and 23.53% were vulnerable to injection attacks (A03:2021).", { indent: true }),
        p("The methodology employed by Flores and Monreal (2024) is directly relevant to this study\u2019s security evaluation approach. Their four-stage research flow\u2014planning, scanning, exploitation, and reporting/recommendations\u2014provides a structured framework for vulnerability assessment that this study adapts for evaluating the financial accounting API. Specifically, their use of OWASP ZAP for automated vulnerability scanning aligns with this study\u2019s use of the same tool for both baseline scanning (passive analysis) and authenticated API scanning (active testing with JWT tokens). Their finding that ZAP detected a significantly larger number of vulnerabilities compared to other scanners validates the tool selection for this research.", { indent: true }),

        heading2("2.6 GPT Language Models for Source Code Security Inspection"),
        p("Szab\u00F3 and Bilicki (2023) proposed a novel approach to web application security that utilizes GPT language models for static source code inspection. Published in Future Internet (MDPI), their research focused specifically on detecting CWE-653 vulnerabilities\u2014inadequately isolated sensitive code segments that could lead to unauthorized access or data leakage\u2014in Angular web applications. Using the GPT API with both GPT-3.5 and GPT-4 models, they applied few-shot learning and chain-of-thought prompting techniques to analyze open-source Angular applications.", { indent: true }),
        p("Their results demonstrated an impressive 88.76% detection success rate for CWE-653 vulnerabilities, with GPT models proving effective in mapping sensitive data paths and categorizing protection levels. The authors compared GPT-3.5 and GPT-4, finding that GPT-4 provided more nuanced analysis and fewer false positives. However, they emphasized that GPT outputs must be augmented with human expertise for broader security scenarios, as the models occasionally produced false positives or missed context-dependent vulnerabilities.", { indent: true }),
        p("This study is foundational for the current research because it demonstrates the feasibility and effectiveness of using GPT models for security-related code inspection. While Szab\u00F3 and Bilicki (2023) focused on front-end Angular applications and CWE-653 detection, the current study extends this approach to back-end ASP.NET Core RESTful APIs, addressing a broader range of security vulnerabilities identified by OWASP ZAP. The finding that chain-of-thought prompting improves detection accuracy informs the prompt engineering strategy used in this study when generating ChatGPT recommendations.", { indent: true }),

        heading2("2.7 Evaluating AI-Generated Code Quality"),
        p("Yeti\u015Ftiren et al. (2023) conducted a comprehensive empirical study comparing the code quality of three AI-assisted code generation tools: GitHub Copilot (powered by OpenAI Codex), Amazon CodeWhisperer, and ChatGPT (GPT-3.5 and GPT-4). Using the HumanEval dataset as their benchmark, they evaluated generated code across five quality dimensions: code validity, code correctness, code security, code reliability, and code maintainability. Static analysis was performed using SonarQube to identify bugs, code smells, and security vulnerabilities.", { indent: true }),
        p("Their analysis revealed that ChatGPT generated correct code 65.2% of the time, significantly outperforming GitHub Copilot (46.3%) and Amazon CodeWhisperer (31.1%). In terms of maintainability, the average technical debt was 8.9 minutes for ChatGPT, 9.1 minutes for GitHub Copilot, and 5.6 minutes for Amazon CodeWhisperer. The newer versions of GitHub Copilot showed an 18% improvement rate, while Amazon CodeWhisperer improved by 7%, indicating the rapid evolution of these tools. ChatGPT\u2019s explanations were noted as being the most user-friendly among the three tools.", { indent: true }),
        p("This study provides the most directly relevant methodological precedent for the current research. The use of SonarQube for evaluating AI-generated code quality aligns perfectly with this study\u2019s methodology, and the performance benchmarks established by Yeti\u015Ftiren et al. (2023) serve as comparison points for evaluating ChatGPT\u2019s effectiveness in the specific context of financial API improvement. Furthermore, their finding that AI tools show promise but face challenges in scalability and real-world deployment reinforces this study\u2019s approach of evaluating ChatGPT recommendations in a realistic, multi-endpoint financial API system rather than isolated programming tasks.", { indent: true }),

        heading2("2.8 AI\u2019s Impact on Developer Productivity"),
        p("Peng et al. (2023) conducted a controlled experiment to measure the productivity impact of GitHub Copilot, published as a Microsoft Research and GitHub collaboration. Their study recruited 95 professional programmers through the Upwork freelancing platform and tasked them with implementing an HTTP server in JavaScript. The treatment group, with access to GitHub Copilot powered by OpenAI\u2019s Codex model, completed the task 55.8% faster than the control group (95% confidence interval: 21\u201389%). The experiment, conducted between May 15 and June 20, 2022, revealed heterogeneous effects: developers with less programming experience, older programmers, and those who programmed more hours per day benefited the most from the AI pair programmer.", { indent: true }),
        p("While this study focused on GitHub Copilot rather than ChatGPT, the findings are highly relevant to the current research for two reasons. First, both tools are built on OpenAI\u2019s language models (Codex for Copilot, and the GPT family for ChatGPT\u2014with this study using ChatGPT 5.4 Codex), sharing similar underlying capabilities for code understanding and generation. Second, the demonstrated productivity gains provide empirical justification for investigating AI tools in development workflows\u2014if AI pair programming can accelerate task completion by over 50%, it is reasonable to hypothesize that AI-guided code recommendations can similarly accelerate the process of identifying and fixing security vulnerabilities and performance bottlenecks. However, Peng et al. (2023) noted limitations in understanding long-term adoption effects and ethical implications, gaps that the current study partially addresses by focusing on measurable security and performance outcomes rather than subjective productivity assessments.", { indent: true }),

        heading2("2.9 Summary of Literature and Research Gaps"),
        p("The reviewed literature establishes several key themes relevant to this study:", { after: 100 }),
        p("First, AI-assisted code generation tools, particularly ChatGPT, have demonstrated significant capabilities in producing functional code, with correctness rates reaching 65.2% (Yeti\u015Ftiren et al., 2023) and developer productivity gains of up to 55.8% (Peng et al., 2023). However, these tools also introduce risks including code smells, security vulnerabilities, and context-dependent errors (S\u00E1godi et al., 2024; Fajkovic & Rundberg, 2023).", { indent: true }),
        p("Second, web API security remains a critical challenge, with empirical evidence showing that the vast majority of web applications contain exploitable vulnerabilities (Flores & Monreal, 2024). GPT language models have shown promise in detecting specific vulnerability types with success rates exceeding 88% (Szab\u00F3 & Bilicki, 2023), but their application to comprehensive API security improvement remains understudied.", { indent: true }),
        p("Third, while existing studies have evaluated AI tools on isolated programming tasks or educational settings, there is a notable gap in research examining how ChatGPT can be applied to improve real-world, multi-endpoint API systems that combine security, performance, and code quality concerns simultaneously. This gap is particularly pronounced in the domain of financial APIs, where the stakes of security failures and performance degradation are especially high.", { indent: true }),
        p("This study addresses these gaps by investigating the practical application of ChatGPT 5.4 Codex for targeted improvements to a financial accounting RESTful API, using a rigorous branch-based methodology with independent verification through three industry-standard tools: SonarQube, OWASP ZAP, and Apache JMeter.", { indent: true }),

        // Summary table of literature
        heading3("Table 2.1: Summary of Reviewed Literature"),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [600, 2400, 1800, 1800, 2760],
          rows: [
            new TableRow({
              children: [
                tableCell("No.", { width: 600, bold: true, shading: "D5E8F0" }),
                tableCell("Study", { width: 2400, bold: true, shading: "D5E8F0" }),
                tableCell("Key Tools/Models", { width: 1800, bold: true, shading: "D5E8F0" }),
                tableCell("Focus Area", { width: 1800, bold: true, shading: "D5E8F0" }),
                tableCell("Key Finding", { width: 2760, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["1", "Fajkovic & Rundberg (2023)", "ChatGPT, Copilot, SonarQube", "Web development", "AI tools generate functional code but introduce bugs/security risks"],
              ["2", "S\u00E1godi et al. (2024)", "ChatGPT, Copilot", "Code synthesis evaluation", "ChatGPT produced more correct solutions; prompt engineering is critical"],
              ["3", "\u00D6zpolat et al. (2023)", "ChatGPT (GPT-3.5, GPT-4)", "Software development", "ChatGPT effective for automation but needs human oversight"],
              ["4", "Chen et al. (2023)", "GPTutor, GPT-3.5 API, VS Code", "Code explanation", "GPTutor provides most concise/accurate code explanations"],
              ["5", "Zhang et al. (2023)", "Stack Overflow, ProgrammableWeb", "Web API issues", "24 issue types identified; security and documentation are top concerns"],
              ["6", "Szab\u00F3 & Bilicki (2023)", "GPT-3.5, GPT-4", "Security inspection", "88.76% detection rate for CWE-653 vulnerabilities"],
              ["7", "Yeti\u015Ftiren et al. (2023)", "ChatGPT, Copilot, CodeWhisperer, SonarQube", "Code quality", "ChatGPT achieves 65.2% correctness; technical debt 8.9 min avg"],
              ["8", "Flores & Monreal (2024)", "OWASP ZAP, OWASP Top 10", "Security vulnerabilities", "94.12% websites vulnerable to broken access control"],
              ["9", "Peng et al. (2023)", "GitHub Copilot (Codex)", "Developer productivity", "55.8% faster task completion with AI pair programming"],
              ["10", "Efuntade & Efuntade (2023)", "APIs, AIS", "Financial API security", "APIs critical for accounting systems; security is paramount"],
              ["11", "Jain et al. (2025)", "GPT-3.5, GPT-4, GPT-4o", "GPT evolution", "No significant performance difference between GPT versions"],
            ].map(([no, study, tools, focus, finding]) =>
              new TableRow({
                children: [
                  tableCell(no, { width: 600 }),
                  tableCell(study, { width: 2400 }),
                  tableCell(tools, { width: 1800 }),
                  tableCell(focus, { width: 1800 }),
                  tableCell(finding, { width: 2760 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 200 }),
      ],
    },
    // ===== CHAPTER 3 - RESEARCH METHODOLOGY =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      headers: {
        default: new Header({
          children: [new Paragraph({
            children: [new TextRun({ text: "Chapter 3: Research Overview and Methodology", font: TNR, size: 18, italics: true })],
            alignment: AlignmentType.RIGHT,
          })],
        }),
      },
      footers: {
        default: new Footer({
          children: [new Paragraph({
            children: [new TextRun({ text: "Page ", font: TNR, size: 20 }), new TextRun({ children: [PageNumber.CURRENT], font: TNR, size: 20 })],
            alignment: AlignmentType.CENTER,
          })],
        }),
      },
      children: [
        heading1("Chapter 3: Research Overview and Methodology", false),

        heading2("3.1 Research Overview"),
        p("This research focuses on improving the security, performance, and code quality of ASP.NET Core 8.0 RESTful APIs by using ChatGPT (ChatGPT 5.4 Codex, OpenAI, 2025\u20132026) to generate recommendations for code enhancements. The study evaluates a financial accounting API project by comparing baseline results with the outcomes after applying ChatGPT-guided improvements. This approach aligns with methodologies established in the literature, where AI-generated code is evaluated through a combination of static analysis and dynamic testing (S\u00E1godi et al., 2024; Yeti\u015Ftiren et al., 2023).", { indent: true }),
        p("The financial accounting API is a multi-tier ASP.NET Core 8.0 application with the following architecture:", { indent: true }),
        p("(a) API Layer \u2014 contains controllers and middleware for handling HTTP requests and responses;", { after: 80 }),
        p("(b) BAL (Business Access Layer/Services) \u2014 implements business logic including journal entry validation, financial calculations, and report generation;", { after: 80 }),
        p("(c) MODEL (Entities) \u2014 defines data models and Entity Framework Core 8.0 database context with SQL Server as the database provider;", { after: 80 }),
        p("(d) Tests \u2014 includes both unit tests and integration tests for validation.", { after: 200 }),
        p("The API exposes 22 endpoints across 7 controllers, organized into two complexity tiers. Simple endpoints perform standard CRUD (Create, Read, Update, Delete) operations with direct database access, while complex endpoints involve multi-step business logic, bulk processing, financial calculations, or report generation. This distinction is important because performance optimization strategies differ significantly between the two tiers\u2014simple endpoints benefit primarily from query optimization and caching, whereas complex endpoints require algorithmic improvements, lazy materialization, and composite indexing (Zhang et al., 2023).", { indent: true }),

        heading3("Table 3.2: Simple API Endpoints (CRUD Operations)"),
        p("Simple endpoints perform single-step data operations with straightforward request-response cycles. These endpoints are characterized by direct database queries, minimal business logic, and predictable resource consumption.", { after: 100 }),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [900, 3000, 2460, 1500, 1500],
          rows: [
            new TableRow({
              children: [
                tableCell("Method", { width: 900, bold: true, shading: "D5E8F0" }),
                tableCell("Endpoint", { width: 3000, bold: true, shading: "D5E8F0" }),
                tableCell("Description", { width: 2460, bold: true, shading: "D5E8F0" }),
                tableCell("Auth Required", { width: 1500, bold: true, shading: "D5E8F0" }),
                tableCell("JMeter Tested", { width: 1500, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["POST", "/auth/login", "Authenticate user with username/password; returns JWT token with role claims", "No (public)", "Yes"],
              ["GET", "/users/me", "Retrieve current authenticated user profile from JWT claims", "Yes (any role)", "Yes"],
              ["GET", "/accounts", "List chart of accounts with optional filtering by type, active status, and search term; supports pagination", "Yes (any role)", "Yes"],
              ["GET", "/accounts/{id}", "Retrieve single account by ID; returns 404 if not found", "Yes (any role)", "No"],
              ["GET", "/accounts/{id}/balance", "Calculate and return current balance for a specific account", "Yes (any role)", "No"],
              ["POST", "/accounts", "Create new chart of accounts entry; logs action with actor ID and IP address", "Yes (Admin)", "No"],
              ["PUT", "/accounts/{id}", "Update existing account properties; logs changes with actor ID and IP", "Yes (Admin)", "No"],
              ["GET", "/periods", "List all accounting periods (open and closed)", "Yes (any role)", "Yes"],
              ["POST", "/periods", "Create new accounting period with start/end dates", "Yes (Admin)", "No"],
              ["POST", "/users", "Create new user account with role assignment", "Yes (Admin)", "No"],
              ["GET", "/journal-entries/{id}", "Retrieve single journal entry by ID with line items", "Yes (any role)", "No"],
              ["GET", "/journal-entries", "List journal entries with pagination and query filters (date range, status, account)", "Yes (any role)", "Yes"],
              ["POST", "/journal-entries", "Create single draft journal entry with debit/credit line items", "Yes (Admin, User, FinanceManager)", "No"],
              ["DELETE", "/journal-entries/{id}", "Delete draft journal entry; prevents deletion of posted entries", "Yes (Admin)", "No"],
            ].map(([method, endpoint, desc, auth, tested]) =>
              new TableRow({
                children: [
                  tableCell(method, { width: 900 }),
                  tableCell(endpoint, { width: 3000 }),
                  tableCell(desc, { width: 2460 }),
                  tableCell(auth, { width: 1500 }),
                  tableCell(tested, { width: 1500 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 200 }),

        heading3("Table 3.3: Complex API Endpoints (Multi-Step Operations)"),
        p("Complex endpoints involve multi-step business logic, financial calculations, bulk data processing, state transitions, or report generation that aggregates data across multiple database tables. These endpoints are the primary targets for ChatGPT-guided performance optimization because they exhibit the highest latency under load.", { after: 100 }),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [900, 3000, 3460, 1000, 1000],
          rows: [
            new TableRow({
              children: [
                tableCell("Method", { width: 900, bold: true, shading: "D5E8F0" }),
                tableCell("Endpoint", { width: 3000, bold: true, shading: "D5E8F0" }),
                tableCell("Description and Complexity", { width: 3460, bold: true, shading: "D5E8F0" }),
                tableCell("Auth", { width: 1000, bold: true, shading: "D5E8F0" }),
                tableCell("Tested", { width: 1000, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["POST", "/journal-entries/bulk", "Bulk create multiple journal entries in a single request. Validates debit/credit balance for each entry, creates line items, and logs the operation. Returns array of created IDs.", "Admin, FM", "Yes"],
              ["POST", "/journal-entries/{id}/post", "Post (finalize) a draft journal entry for accounting. Validates entry status, updates balances across affected accounts, changes status from Draft to Posted, and logs the state change.", "Admin, FM", "No"],
              ["POST", "/journal-entries/{id}/reverse", "Reverse a posted journal entry. Creates a new reversing entry with opposite debit/credit amounts, links it to the original, posts the reversal, and logs both the original and reversal.", "Admin, FM", "No"],
              ["POST", "/periods/{id}/close", "Close an accounting period. Validates all entries are posted, prevents further entries to the period, updates period status, and logs the closure.", "Admin, FM", "No"],
              ["GET", "/reports/trial-balance", "Generate trial balance report for a specified period. Aggregates all posted journal entry line items by account, calculates total debits and credits, verifies the trial balance equation (total debits = total credits).", "Admin, FM, Auditor", "Yes"],
              ["GET", "/reports/profit-loss", "Generate Profit & Loss (income statement) for a period. Queries all revenue and expense accounts, calculates net income/loss, groups by account category, and returns formatted report.", "Admin, FM, Auditor", "Yes"],
              ["GET", "/reports/balance-sheet", "Generate Balance Sheet for a period. Aggregates assets, liabilities, and equity accounts, calculates totals for each category, verifies the accounting equation (Assets = Liabilities + Equity).", "Admin, FM, Auditor", "Yes"],
              ["GET", "/reports/account-ledger", "Generate detailed account ledger for a specific account and period. Returns all journal entry line items affecting the account with running balance calculation. Highest latency endpoint.", "Admin, FM, Auditor", "Yes"],
            ].map(([method, endpoint, desc, auth, tested]) =>
              new TableRow({
                children: [
                  tableCell(method, { width: 900 }),
                  tableCell(endpoint, { width: 3000 }),
                  tableCell(desc, { width: 3460 }),
                  tableCell(auth, { width: 1000 }),
                  tableCell(tested, { width: 1000 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 100 }),
        p("In total, 14 endpoints are classified as simple CRUD operations and 8 endpoints are classified as complex multi-step operations. Of the 22 endpoints, 12 are included in the JMeter performance test matrix, covering the most performance-critical paths: authentication, data retrieval, bulk operations, and all four financial report endpoints. The report endpoints (trial-balance, profit-loss, balance-sheet, account-ledger) are the primary performance hotspots because they aggregate data across thousands of posted journal entries and must compute financial totals in real time.", { indent: true }),
        p("This research is important because RESTful APIs are critical components in modern financial software systems, yet they often suffer from vulnerabilities like SQL injection, XSS, and performance bottlenecks that can expose sensitive financial data (Flores & Monreal, 2024; Efuntade & Efuntade, 2023). By leveraging ChatGPT, this research aims to demonstrate how AI can assist developers in enhancing API security, reliability, and maintainability\u2014areas where manual processes are time-consuming and error-prone (\u00D6zpolat et al., 2023).", { indent: true }),

        heading2("3.2 Workflow of Overall Research Experiment"),
        p("The research follows a four-phase experimental workflow, each addressing a core objective of the study. This branch-based methodology ensures that improvements from each tool are isolated and independently verifiable, following the principle of controlled experimentation established in prior AI evaluation studies (Peng et al., 2023; Yeti\u015Ftiren et al., 2023).", { indent: true }),

        heading3("Phase 1: Baseline Analysis"),
        p("Initial security, performance, and code quality testing are conducted on the financial accounting API. Baseline metrics are captured on the baseline-v0.1 branch and provide reference points for evaluating the effectiveness of improvements. The baseline analysis establishes the current state of the API across three dimensions:", { indent: true }),
        p([{ text: "Security (OWASP ZAP): ", bold: true }, { text: "Two scan types are executed\u2014a baseline scan (passive analysis of all endpoint responses for security header issues, cookie attributes, and information disclosure) and an authenticated API scan (active testing with JWT tokens targeting all business endpoints with role-based access). The baseline scan identified 11 alerts: 0 High, 2 Medium (missing Content Security Policy header, missing Anti-CSRF tokens), 6 Low (missing X-Content-Type-Options header, Server Leaks Version Information via Server HTTP Response Header, Cookie without SameSite attribute, Cross-Domain Misconfiguration, Timestamp Disclosure \u2013 Unix, X-Content-Type-Options header missing), and 3 Informational alerts. The authenticated API scan found 8 alerts: 0 High, 0 Medium, 3 Low, and 5 Informational." }], { after: 200 }),
        p([{ text: "Performance (Apache JMeter 5.5): ", bold: true }, { text: "Performance testing runs in Docker containers using the justb4/jmeter:5.5 image for reproducible results. Five test profiles are executed: load tests at 50, 100, and 500 concurrent users, a soak test (100 users sustained over 180 iterations), and a spike test (500 users with 30-second ramp-up). All 16 API endpoints are tested. Baseline results showed p95 response time of 261.95 ms at 100 concurrent users, 49.45 ms at 50 users, 176.00 ms at 500 users, 970.95 ms during soak test, and 6795.00 ms during spike test. The hotspot endpoint was GET /reports/account-ledger at 1783.95 ms (soak) and 8073.40 ms (spike)." }], { after: 200 }),
        p([{ text: "Code Quality (SonarQube Community Edition v24.12): ", bold: true }, { text: "Static code analysis is performed using dotnet-sonarscanner with unit and integration test coverage analysis. The baseline scan identified 21 code smells and 28 total C# findings, with 0 bugs, 0 vulnerabilities, and 0 security hotspots. The quality gate status, code coverage percentage, and duplicated lines density are tracked as additional metrics." }], { after: 200 }),

        heading3("Phase 2: ChatGPT-Generated Improvements"),
        p("Code recommendations are generated using ChatGPT (ChatGPT 5.4 Codex, OpenAI, 2025\u20132026). For each identified issue from the baseline analysis, the specific finding is provided to ChatGPT along with the relevant code context, and ChatGPT generates targeted recommendations for remediation. Each tool\u2019s fixes are applied on a dedicated branch to isolate changes for clear before/after comparison:", { indent: true }),
        p([{ text: "baseline-sonarqube-v1: ", bold: true }, { text: "Code quality improvements including removal of code smells, reduction of cyclomatic complexity, and adherence to clean code principles." }], { after: 100 }),
        p([{ text: "baseline-zap-v1: ", bold: true }, { text: "Security fixes including adding Content Security Policy headers, implementing anti-CSRF token validation, removing server version information from HTTP responses, adding SameSite attributes to cookies, and fixing cross-domain misconfiguration." }], { after: 100 }),
        p([{ text: "baseline-jmeter-v1: ", bold: true }, { text: "Performance optimizations including implementing caching for frequently accessed endpoints, optimizing database queries, improving data-fetching algorithms, implementing pagination, and managing connection pooling." }], { after: 200 }),
        p("This branch-based approach follows established software engineering practices for isolating changes and ensures that improvements from each tool can be independently verified and attributed (S\u00E1godi et al., 2024).", { indent: true }),

        heading3("Phase 3: Post-Improvement Testing"),
        p("With ChatGPT-guided changes implemented on each branch, the project undergoes a new round of testing using the same tools, configurations, and test environments as the baseline. This ensures that any observed differences are attributable to the code changes rather than environmental variations. Security, performance, and code quality metrics are collected again and compared to the baseline-v0.1 results.", { indent: true }),

        heading3("Phase 4: Comparative Analysis and Reporting"),
        p("The data collected from the baseline (baseline-v0.1) and post-improvement branches (baseline-sonarqube-v1, baseline-zap-v1, baseline-jmeter-v1) are analyzed and compared side by side to draw conclusions on ChatGPT\u2019s effectiveness. Results are compiled into a baseline-comparison-report documenting improvements across all three dimensions with specific metrics, percentages, and before/after comparisons.", { indent: true }),

        heading2("3.3 Dataset Description and Preparation"),
        p("The dataset comprises simulated financial accounting data designed to evaluate the impact of security and performance improvements in a realistic scenario. The data is generated locally as part of the API\u2019s seed data mechanism and does not originate from any public dataset or real financial institution. This approach ensures that all test data is purpose-built for the specific endpoint categories and data relationships required by the financial accounting API.", { indent: true }),
        p([{ text: "Transactional Data: ", bold: true }, { text: "1,000 to 1,000,000 records with fields including TransactionID (auto-increment), AccountID (linked to chart of accounts), Amount ($0 to $1,000,000), Date (spanning multiple years), Currency (supporting USD, EUR, THB, GBP, JPY), Status (Completed, Pending, Failed, Reversed), and Description (text field for transaction details)." }], { after: 100 }),
        p([{ text: "User Data: ", bold: true }, { text: "50\u2013100 users with fields including UserID, Username, Role (Admin, User, Auditor, FinanceManager), and PasswordHash (properly hashed using industry-standard algorithms). Users are assigned roles for testing role-based access control (RBAC) enforcement across all API endpoints." }], { after: 100 }),
        p([{ text: "Reports Data: ", bold: true }, { text: "100+ report records with fields including ReportID, DateRange (customizable daily, weekly, monthly intervals), TotalTransactions (dynamic counts), TotalAmount (summed values with multi-currency support), and CurrencyBreakdown (nested field for detailed breakdowns)." }], { after: 200 }),

        heading2("3.4 Model and Tool Selection"),
        p("This research employs a carefully selected combination of AI models and evaluation tools. The specific versions are documented to ensure reproducibility, following best practices established in empirical software engineering research (Yeti\u015Ftiren et al., 2023; S\u00E1godi et al., 2024).", { indent: true }),

        heading3("Table 3.1: Models and Tools Used in This Study"),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [2200, 1600, 2000, 3560],
          rows: [
            new TableRow({
              children: [
                tableCell("Tool/Model", { width: 2200, bold: true, shading: "D5E8F0" }),
                tableCell("Version", { width: 1600, bold: true, shading: "D5E8F0" }),
                tableCell("Platform", { width: 2000, bold: true, shading: "D5E8F0" }),
                tableCell("Purpose", { width: 3560, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["ChatGPT", "5.4 Codex", "OpenAI web interface", "Generate code improvement recommendations for security, performance, and code quality"],
              ["ASP.NET Core", "8.0", ".NET SDK 8.0", "Target framework for the financial accounting RESTful API"],
              ["Entity Framework Core", "8.0.13", "NuGet package", "ORM for SQL Server database operations"],
              ["SQL Server", "Latest (localhost)", "Windows 11", "Database backend for financial accounting data"],
              ["SonarQube", "Community Ed. v24.12", "Docker container", "Static code analysis: bugs, vulnerabilities, code smells, coverage"],
              ["dotnet-sonarscanner", "Latest", ".NET global tool", "Integration between .NET projects and SonarQube"],
              ["Apache JMeter", "5.5", "Docker (justb4/jmeter:5.5)", "Performance testing: load, soak, spike test profiles"],
              ["OWASP ZAP", "Stable (2024)", "Docker (ghcr.io/zaproxy/zaproxy:stable)", "Security scanning: baseline and authenticated API scans"],
              ["Docker Desktop", "Latest", "Windows 11", "Container runtime for SonarQube, JMeter, and ZAP"],
              ["Git", "Latest", "Windows 11", "Version control with branch-based testing methodology"],
              ["Windows 11", "Home", "Development machine", "Operating system for development and testing"],
            ].map(([tool, ver, platform, purpose]) =>
              new TableRow({
                children: [
                  tableCell(tool, { width: 2200 }),
                  tableCell(ver, { width: 1600 }),
                  tableCell(platform, { width: 2000 }),
                  tableCell(purpose, { width: 3560 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 200 }),

        heading2("3.5 Implementation of ChatGPT-Guided Improvements"),
        p("After baseline testing, ChatGPT 5.4 Codex is used to generate improvement suggestions for each issue identified by the three evaluation tools. The process follows an iterative prompt-response cycle where each identified issue is presented to ChatGPT along with the relevant code context, and ChatGPT generates a specific code recommendation. This approach aligns with the prompt engineering best practices identified by S\u00E1godi et al. (2024) and the chain-of-thought techniques used by Szab\u00F3 and Bilicki (2023).", { indent: true }),

        heading3("3.5.1 Security Enhancements (baseline-zap-v1)"),
        p("ChatGPT-guided security improvements address each vulnerability identified by OWASP ZAP:", { after: 100 }),
        p("(a) Content Security Policy (CSP) Header: ChatGPT recommended adding CSP middleware to the ASP.NET Core pipeline with appropriate directives for script-src, style-src, and default-src to prevent XSS attacks.", { after: 80 }),
        p("(b) Anti-CSRF Tokens: Implementation of anti-forgery token validation for state-changing endpoints (POST, PUT, DELETE) using ASP.NET Core\u2019s built-in antiforgery middleware.", { after: 80 }),
        p("(c) Server Information Leakage: Removal of Server header and version information from HTTP responses by configuring Kestrel server options.", { after: 80 }),
        p("(d) Cookie SameSite Attribute: Configuration of SameSite=Strict attribute on all authentication cookies to prevent CSRF attacks.", { after: 80 }),
        p("(e) X-Content-Type-Options Header: Addition of X-Content-Type-Options: nosniff header to prevent MIME-type sniffing.", { after: 80 }),
        p("(f) Cross-Domain Misconfiguration: Proper CORS policy configuration restricting allowed origins, methods, and headers.", { after: 200 }),

        heading3("3.5.2 Performance Optimizations (baseline-jmeter-v1)"),
        p("ChatGPT-guided performance improvements target the bottlenecks identified by JMeter:", { after: 100 }),
        p("(a) Response Caching: Implementation of in-memory caching for frequently accessed endpoints, particularly financial reports (trial balance, profit & loss, balance sheet), with configurable cache duration.", { after: 80 }),
        p("(b) Query Optimization: Optimization of Entity Framework Core queries by adding appropriate indexes, using AsNoTracking() for read-only operations, and implementing eager loading to prevent N+1 query problems.", { after: 80 }),
        p("(c) Connection Pooling: Configuration of SQL Server connection pooling parameters for optimal performance under concurrent load.", { after: 80 }),
        p("(d) Pagination: Implementation of server-side pagination for list endpoints to reduce payload sizes and database load.", { after: 200 }),

        heading3("3.5.3 Code Quality Improvements (baseline-sonarqube-v1)"),
        p("ChatGPT-guided code quality improvements address each finding from SonarQube:", { after: 100 }),
        p("(a) Code Smells: Refactoring of 21 code smells including unused variables, overly complex methods, and non-standard naming conventions.", { after: 80 }),
        p("(b) Cyclomatic Complexity: Simplification of complex conditional logic through extraction of methods and use of pattern matching.", { after: 80 }),
        p("(c) Maintainability: Improvement of code structure, adherence to SOLID principles, and reduction of technical debt.", { after: 200 }),

        heading2("3.6 Testing Phases"),
        p("Each testing phase uses identical tool configurations to ensure comparability:", { indent: true }),
        p([{ text: "Baseline Testing (baseline-v0.1): ", bold: true }, { text: "The initial state of the financial accounting API is tested for security (ZAP baseline + API scan), performance (JMeter load at 50/100/500 users + soak + spike), and code quality (SonarQube). All results are recorded with timestamps and tool output files for reproducibility." }], { after: 100 }),
        p([{ text: "Post-Improvement Testing: ", bold: true }, { text: "After implementing ChatGPT\u2019s improvements on dedicated branches (baseline-sonarqube-v1, baseline-zap-v1, baseline-jmeter-v1), each branch is re-tested with the same tool and configuration. All issues and fixes are documented in per-tool fix tracking documents. The use of Docker containers for JMeter (justb4/jmeter:5.5) and ZAP (ghcr.io/zaproxy/zaproxy:stable) ensures identical scanner behavior across runs." }], { after: 200 }),

        heading2("3.7 How is This Research Different from Prior Studies?"),
        p("This study distinguishes itself from prior research in several important ways:", { indent: true }),
        p([{ text: "Focus on ChatGPT for API Improvement: ", bold: true }, { text: "Unlike studies that evaluate AI tools on isolated programming tasks (Yeti\u015Ftiren et al., 2023; S\u00E1godi et al., 2024) or compare multiple AI tools (Fajkovic & Rundberg, 2023), this research focuses exclusively on ChatGPT 5.4 Codex applied to a real-world, multi-endpoint financial API system." }], { after: 100 }),
        p([{ text: "Integrated Multi-Tool Evaluation: ", bold: true }, { text: "This study uniquely integrates security (OWASP ZAP), performance (Apache JMeter), and code quality (SonarQube) testing in a single workflow, providing a holistic view of ChatGPT\u2019s impact that prior studies have not achieved." }], { after: 100 }),
        p([{ text: "Branch-Based Methodology: ", bold: true }, { text: "The use of dedicated Git branches for each tool\u2019s improvements enables isolated, independently verifiable before/after comparisons\u2014a methodological approach not found in existing AI code evaluation literature." }], { after: 100 }),
        p([{ text: "Financial Domain Focus: ", bold: true }, { text: "By using financial accounting data and a system with role-based access control, JWT authentication, and comprehensive audit logging, this research tests ChatGPT\u2019s capabilities in a domain where security and reliability are non-negotiable (Efuntade & Efuntade, 2023)." }], { after: 200 }),
      ],
    },
    // ===== CHAPTER 4 - EVALUATION PLAN =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      headers: {
        default: new Header({
          children: [new Paragraph({
            children: [new TextRun({ text: "Chapter 4: Evaluation Plan and Metrics", font: TNR, size: 18, italics: true })],
            alignment: AlignmentType.RIGHT,
          })],
        }),
      },
      footers: {
        default: new Footer({
          children: [new Paragraph({
            children: [new TextRun({ text: "Page ", font: TNR, size: 20 }), new TextRun({ children: [PageNumber.CURRENT], font: TNR, size: 20 })],
            alignment: AlignmentType.CENTER,
          })],
        }),
      },
      children: [
        heading1("Chapter 4: Evaluation Plan and Metrics", false),

        heading2("4.1 Evaluation Criteria"),
        p("The evaluation of ChatGPT\u2019s effectiveness in improving the financial accounting API is structured around three pillars: security, performance, and code quality. Each pillar employs specific metrics measured in defined units, enabling objective, quantitative comparison between baseline and post-improvement results. This multi-dimensional evaluation approach is supported by the literature, where Yeti\u015Ftiren et al. (2023) demonstrated the importance of evaluating AI-generated code across multiple quality dimensions, and Flores and Monreal (2024) established the value of structured vulnerability assessment frameworks.", { indent: true }),

        heading3("4.1.1 Security Metrics"),
        p([{ text: "Number of Vulnerabilities: ", bold: true }, { text: "Measured as the count of alerts detected by OWASP ZAP across both baseline scan (passive) and authenticated API scan (active), categorized by severity level: High, Medium, Low, and Informational. This metric directly follows the OWASP risk assessment methodology used by Flores and Monreal (2024)." }], { after: 100 }),
        p([{ text: "Severity Distribution: ", bold: true }, { text: "Analysis of alert distribution across severity levels, tracking the reduction of high-severity issues as the primary indicator of security improvement." }], { after: 100 }),
        p([{ text: "Vulnerability Categories: ", bold: true }, { text: "Specific vulnerabilities are tracked and compared before and after improvement:" }], { after: 80 }),

        heading3("Table 4.1: Security Vulnerabilities \u2014 Before vs. After Comparison"),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [3200, 1200, 1200, 1200, 2560],
          rows: [
            new TableRow({
              children: [
                tableCell("Vulnerability", { width: 3200, bold: true, shading: "D5E8F0" }),
                tableCell("Severity", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("Before", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("After", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("Change", { width: 2560, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["Missing Content Security Policy", "Medium", "Present", "Resolved", "CSP header added"],
              ["Missing Anti-CSRF Tokens", "Medium", "Present", "Resolved", "Antiforgery middleware added"],
              ["Missing X-Content-Type-Options", "Low", "Present", "Resolved", "nosniff header added"],
              ["Server Leaks Version Info", "Low", "Present", "Resolved", "Server header removed"],
              ["Cookie without SameSite", "Low", "Present", "Resolved", "SameSite=Strict set"],
              ["Cross-Domain Misconfiguration", "Low", "Present", "Resolved", "CORS policy restricted"],
              ["Timestamp Disclosure \u2013 Unix", "Low", "Present", "Resolved", "Timestamps sanitized"],
              ["X-Content-Type-Options Missing", "Low", "Present", "Resolved", "Header added globally"],
              ["Total Medium Alerts", "", "2", "0", "\u2013100%"],
              ["Total Low Alerts", "", "9", "0", "\u2013100%"],
              ["Total Informational", "", "8", "9", "Informational only"],
            ].map(([vuln, sev, before, after, change]) =>
              new TableRow({
                children: [
                  tableCell(vuln, { width: 3200 }),
                  tableCell(sev, { width: 1200 }),
                  tableCell(before, { width: 1200 }),
                  tableCell(after, { width: 1200 }),
                  tableCell(change, { width: 2560 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 200 }),

        heading3("4.1.2 Performance Metrics"),
        p([{ text: "Response Time: ", bold: true }, { text: "Measured in milliseconds (ms), specifically the p95 (95th percentile) response time, which represents the response time below which 95% of requests fall. This metric is captured for all 16 API endpoints under each load profile (50, 100, 500 concurrent users, soak, and spike tests)." }], { after: 100 }),
        p([{ text: "Throughput: ", bold: true }, { text: "Measured in transactions per second (tx/s), representing the number of successful API requests processed per second under each load profile." }], { after: 100 }),
        p([{ text: "Error Rate: ", bold: true }, { text: "Measured as a percentage (%) of failed requests relative to total requests. A 0% error rate indicates that all requests were processed successfully." }], { after: 100 }),
        p([{ text: "Resource Utilization: ", bold: true }, { text: "While CPU and memory usage are not directly measured by JMeter, they are inferred from latency reduction patterns. Significant latency reductions under sustained load indicate reduced resource contention." }], { after: 200 }),

        heading3("Table 4.2: Performance Metrics \u2014 Before vs. After Comparison"),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [2400, 1600, 1600, 1200, 2560],
          rows: [
            new TableRow({
              children: [
                tableCell("Test Profile", { width: 2400, bold: true, shading: "D5E8F0" }),
                tableCell("Baseline p95 (ms)", { width: 1600, bold: true, shading: "D5E8F0" }),
                tableCell("After p95 (ms)", { width: 1600, bold: true, shading: "D5E8F0" }),
                tableCell("Change", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("Error Rate", { width: 2560, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["50 Concurrent Users", "49.45", "13.00", "\u201373.71%", "0.00% \u2192 0.00%"],
              ["100 Concurrent Users", "261.95", "34.00", "\u201387.02%", "0.00% \u2192 0.00%"],
              ["500 Concurrent Users", "176.00", "28.00", "\u201384.09%", "0.00% \u2192 0.00%"],
              ["Soak Test (100 users)", "970.95", "56.00", "\u201394.23%", "0.00% \u2192 0.00%"],
              ["Spike Test (500 users)", "6795.00", "1420.00", "\u201379.10%", "0.00% \u2192 0.00%"],
            ].map(([profile, before, after, change, error]) =>
              new TableRow({
                children: [
                  tableCell(profile, { width: 2400 }),
                  tableCell(before, { width: 1600 }),
                  tableCell(after, { width: 1600 }),
                  tableCell(change, { width: 1200 }),
                  tableCell(error, { width: 2560 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 200 }),
        p("The performance improvements demonstrate a consistent 73\u201394% reduction in p95 response times across all load profiles. The most dramatic improvement was observed in soak testing, where the p95 response time dropped from 970.95 ms to 56.00 ms (94.23% reduction), indicating that ChatGPT\u2019s recommendations effectively addressed sustained-load performance degradation. Throughput improved by 3.98% from 57.53 to 59.82 transactions/second at 100 concurrent users, suggesting that the application was latency-bound rather than throughput-bound. These results align with the productivity gains demonstrated by Peng et al. (2023), though measured in API performance rather than developer task completion.", { indent: true }),

        heading3("Table 4.2a: Per-Endpoint Performance at 100 Concurrent Users (Post-Improvement)"),
        p("The following table presents the per-endpoint breakdown at 100 concurrent users (mixed mode: 70 core + 30 complex users), showing how simple and complex endpoints differ in performance characteristics.", { after: 100 }),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [800, 2800, 900, 1200, 1200, 1200, 1160],
          rows: [
            new TableRow({
              children: [
                tableCell("Type", { width: 800, bold: true, shading: "D5E8F0" }),
                tableCell("Endpoint", { width: 2800, bold: true, shading: "D5E8F0" }),
                tableCell("Samples", { width: 900, bold: true, shading: "D5E8F0" }),
                tableCell("Avg (ms)", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("p95 (ms)", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("Max (ms)", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("tx/s", { width: 1160, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["Simple", "POST /auth/login", "100", "18.45", "22.30", "310", "1.70"],
              ["Simple", "GET /users/me", "1,000", "6.64", "6.00", "485", "13.37"],
              ["Simple", "GET /accounts", "700", "15.21", "14.00", "543", "10.57"],
              ["Simple", "GET /periods", "700", "6.59", "5.00", "317", "10.57"],
              ["Simple", "GET /journal-entries", "700", "12.72", "16.00", "178", "10.57"],
              ["Complex", "POST /journal-entries/bulk", "300", "18.02", "20.90", "441", "4.09"],
              ["Complex", "GET /reports/trial-balance", "300", "11.78", "10.00", "558", "4.10"],
              ["Complex", "GET /reports/profit-loss", "300", "11.50", "12.00", "362", "4.12"],
              ["Complex", "GET /reports/balance-sheet", "300", "8.12", "11.00", "59", "4.12"],
              ["Complex", "GET /reports/account-ledger", "300", "67.77", "93.00", "1,704", "4.12"],
              ["", "TOTAL", "4,700", "14.43", "26.00", "1,704", "61.24"],
            ].map(([type, endpoint, samples, avg, p95, max, txs]) =>
              new TableRow({
                children: [
                  tableCell(type, { width: 800, bold: type === "" }),
                  tableCell(endpoint, { width: 2800, bold: type === "" }),
                  tableCell(samples, { width: 900 }),
                  tableCell(avg, { width: 1200 }),
                  tableCell(p95, { width: 1200 }),
                  tableCell(max, { width: 1200 }),
                  tableCell(txs, { width: 1160 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 100 }),
        p("The results show that simple CRUD endpoints (GET /users/me, GET /periods) achieve sub-10ms p95 response times, while the most complex endpoint (GET /reports/account-ledger) exhibits the highest latency at 93ms p95 due to its need to compute running balances across thousands of journal entry line items. The bulk journal entry creation endpoint (POST /journal-entries/bulk) performs well at 20.90ms p95 despite its multi-step validation and insertion logic.", { indent: true }),

        heading3("Table 4.2b: Complex Endpoint Hotspot Analysis \u2014 Before vs. After"),
        p("The complex report-generation endpoints showed the most dramatic improvements because ChatGPT\u2019s recommendations targeted their specific bottlenecks: unoptimized database queries, missing composite indexes, and eager materialization of large result sets.", { after: 100 }),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [2500, 1100, 1400, 1400, 1000, 1960],
          rows: [
            new TableRow({
              children: [
                tableCell("Endpoint", { width: 2500, bold: true, shading: "D5E8F0" }),
                tableCell("Profile", { width: 1100, bold: true, shading: "D5E8F0" }),
                tableCell("Before p95", { width: 1400, bold: true, shading: "D5E8F0" }),
                tableCell("After p95", { width: 1400, bold: true, shading: "D5E8F0" }),
                tableCell("Change", { width: 1000, bold: true, shading: "D5E8F0" }),
                tableCell("Fix Applied", { width: 1960, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["/reports/account-ledger", "Soak", "1,783.95 ms", "279.00 ms", "\u201384.4%", "Composite index + caching"],
              ["/reports/account-ledger", "Spike", "8,073.40 ms", "3,435.95 ms", "\u201357.4%", "Composite index + caching"],
              ["/reports/trial-balance", "Spike", "10,585.00 ms", "1,244.85 ms", "\u201388.2%", "Lazy materialization"],
              ["/reports/profit-loss", "Spike", "7,118.35 ms", "690.90 ms", "\u201390.3%", "Lazy materialization"],
              ["/reports/balance-sheet", "Spike", "5,768.95 ms", "650.95 ms", "\u201388.7%", "Lazy materialization"],
              ["/journal-entries/bulk", "Spike", "1,401.70 ms", "634.00 ms", "\u201354.8%", "System optimization"],
            ].map(([endpoint, profile, before, after, change, fix]) =>
              new TableRow({
                children: [
                  tableCell(endpoint, { width: 2500 }),
                  tableCell(profile, { width: 1100 }),
                  tableCell(before, { width: 1400 }),
                  tableCell(after, { width: 1400 }),
                  tableCell(change, { width: 1000 }),
                  tableCell(fix, { width: 1960 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 100 }),
        p("The most significant performance gain was on the GET /reports/profit-loss endpoint during spike testing, which improved by 90.3% (from 7,118.35 ms to 690.90 ms). ChatGPT\u2019s recommendation of lazy materialization\u2014deferring the construction of LedgerBalance objects until they are actually needed rather than eagerly creating them for all accounts\u2014proved to be the single most impactful optimization across all report endpoints. The account-ledger endpoint, which computes a running balance across all journal entry line items for a specific account, showed the smallest spike-test improvement (57.4%) because its bottleneck involves sequential balance computation that is inherently difficult to parallelize.", { indent: true }),

        heading3("4.1.3 Code Quality Metrics"),
        p([{ text: "Code Smells: ", bold: true }, { text: "Count of code patterns that indicate potential maintainability issues, as detected by SonarQube\u2019s static analysis. This metric aligns with the code quality evaluation methodology used by Yeti\u015Ftiren et al. (2023) and Fajkovic and Rundberg (2023), who both employed SonarQube for code smell detection." }], { after: 100 }),
        p([{ text: "Bugs: ", bold: true }, { text: "Count of code patterns that are demonstrably wrong and could lead to runtime errors." }], { after: 100 }),
        p([{ text: "Vulnerabilities: ", bold: true }, { text: "Count of code-level security vulnerabilities identified through static analysis (distinct from runtime vulnerabilities detected by OWASP ZAP)." }], { after: 100 }),
        p([{ text: "Security Hotspots: ", bold: true }, { text: "Count of security-sensitive code patterns that require manual review." }], { after: 100 }),
        p([{ text: "Quality Gate: ", bold: true }, { text: "SonarQube\u2019s aggregate pass/fail assessment based on all configured conditions." }], { after: 100 }),
        p([{ text: "Coverage: ", bold: true }, { text: "Percentage of code covered by unit and integration tests." }], { after: 100 }),
        p([{ text: "Duplicated Lines Density: ", bold: true }, { text: "Percentage of duplicated code lines in the codebase." }], { after: 200 }),

        heading3("Table 4.3: Code Quality Metrics \u2014 Before vs. After Comparison"),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [2800, 2200, 2200, 2160],
          rows: [
            new TableRow({
              children: [
                tableCell("Metric", { width: 2800, bold: true, shading: "D5E8F0" }),
                tableCell("Baseline (v0.1)", { width: 2200, bold: true, shading: "D5E8F0" }),
                tableCell("After (sonarqube-v1)", { width: 2200, bold: true, shading: "D5E8F0" }),
                tableCell("Change", { width: 2160, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["Code Smells", "21", "0", "\u2013100%"],
              ["Total C# Findings", "28", "0", "\u2013100%"],
              ["Bugs", "0", "0", "No change"],
              ["Vulnerabilities", "0", "0", "No change"],
              ["Security Hotspots", "0", "0", "No change"],
              ["Quality Gate", "OK", "OK", "Maintained"],
              ["Coverage", "N/A", "74.3%", "Tracked"],
              ["Duplicated Lines", "N/A", "0.0%", "No duplication"],
            ].map(([metric, before, after, change]) =>
              new TableRow({
                children: [
                  tableCell(metric, { width: 2800 }),
                  tableCell(before, { width: 2200 }),
                  tableCell(after, { width: 2200 }),
                  tableCell(change, { width: 2160 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 100 }),

        heading3("Table 4.3a: Detailed SonarQube Issues Found and Fixed"),
        p("The following table lists all 28 SonarQube findings from the baseline scan and the ChatGPT-recommended fix applied for each. This demonstrates the specific code patterns that ChatGPT identified and remediated.", { after: 100 }),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [1000, 1200, 2600, 4560],
          rows: [
            new TableRow({
              children: [
                tableCell("Rule ID", { width: 1000, bold: true, shading: "D5E8F0" }),
                tableCell("Severity", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("File", { width: 2600, bold: true, shading: "D5E8F0" }),
                tableCell("Fix Description", { width: 4560, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["CS8618 (x14)", "Warning", "MODEL/DataContext.cs", "Replaced settable DbSet properties with expression-bodied Set<T>() accessors to resolve nullability warnings"],
              ["S125", "Warning", "MODEL/DataContext.cs", "Removed commented-out entity configuration block (dead code)"],
              ["S6966", "Warning", "API/Program.cs", "Changed app.Run() to await app.RunAsync() for proper async shutdown"],
              ["S1118", "Warning", "API/Program.cs", "Added protected constructor to Program partial type to prevent instantiation"],
              ["S1118", "Warning", "BAL/ServiceManager.cs", "Converted to static class and removed unused imports"],
              ["S107", "Warning", "Controllers/JournalEntriesController.cs", "Introduced JournalEntryQueryDto to consolidate 6+ query parameters into single object"],
              ["S107", "Warning", "BAL/IJournalEntryService.cs", "Updated service interface to accept JournalEntryQueryDto instead of individual parameters"],
              ["S1192 (x3)", "Warning", "BAL/JournalEntryService.cs", "Extracted repeated string literals (Draft, Posted, JournalEntries) into named constants"],
              ["CA1862", "Note", "BAL/FinancialAuthService.cs", "Switched to StringComparison.OrdinalIgnoreCase after materializing roles from database"],
              ["S3260", "Warning", "BAL/FinancialReportService.cs", "Marked nested AccountAggregate type as sealed to prevent unintended inheritance"],
              ["xUnit1042", "Note", "tests/RbacMatrixTests.cs", "Replaced untyped MemberData with strongly-typed TheoryData<string, string>"],
              ["CA1861 (x2)", "Note", "tests/RbacMatrixTests.cs, tests/FinancialTokenProviderTests.cs", "Hoisted inline constant arrays to static readonly fields to avoid repeated allocation"],
              ["S117,S6975,S6952", "Mixed", "Properties/profile.arm.json", "Fixed ARM template: camelCase variables, proper resource ordering, removed redundant dependencies"],
            ].map(([rule, sev, file, fix]) =>
              new TableRow({
                children: [
                  tableCell(rule, { width: 1000 }),
                  tableCell(sev, { width: 1200 }),
                  tableCell(file, { width: 2600 }),
                  tableCell(fix, { width: 4560 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 100 }),
        p("The most prevalent issue was CS8618 (non-nullable property not initialized), which appeared 14 times in the Entity Framework Core DataContext class. ChatGPT recommended replacing traditional settable DbSet properties with expression-bodied accessors using Set<T>(), which both resolved the nullability warnings and improved code clarity. The second most impactful fix was S107 (too many parameters), where ChatGPT suggested introducing a Data Transfer Object (JournalEntryQueryDto) to consolidate six individual query parameters into a single typed object\u2014a refactoring that improved both maintainability and API discoverability.", { indent: true }),

        heading3("Table 4.3b: Security Attack Test Results (OWASP ZAP Active Scan)"),
        p("Beyond passive header checks, OWASP ZAP performed active security testing against all API endpoints, attempting common attack patterns. The following table confirms that the financial accounting API is resistant to all tested attack categories.", { after: 100 }),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [2800, 1600, 2400, 2560],
          rows: [
            new TableRow({
              children: [
                tableCell("Attack Category", { width: 2800, bold: true, shading: "D5E8F0" }),
                tableCell("ZAP Rule IDs", { width: 1600, bold: true, shading: "D5E8F0" }),
                tableCell("Test Description", { width: 2400, bold: true, shading: "D5E8F0" }),
                tableCell("Result", { width: 2560, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["SQL Injection", "40018\u201340022, 40027", "Time-based and standard SQLi payloads on all input parameters", "PASS (0 hits)"],
              ["Reflected XSS", "40012", "Script injection in query and body parameters", "PASS (0 hits)"],
              ["Persistent XSS", "40014", "Stored data injection via POST endpoints", "PASS (0 hits)"],
              ["DOM-based XSS", "40026", "Client-side script manipulation attempts", "PASS (0 hits)"],
              ["Remote Code Execution", "90020, 90037", "OS command injection attempts", "PASS (0 hits)"],
              ["Path Traversal", "6", "Directory traversal sequences in URL parameters", "PASS (0 hits)"],
              ["RBAC Enforcement", "\u2014", "Role boundary violations (e.g., User accessing Admin endpoints)", "ALL CORRECT"],
            ].map(([cat, rules, desc, result]) =>
              new TableRow({
                children: [
                  tableCell(cat, { width: 2800 }),
                  tableCell(rules, { width: 1600 }),
                  tableCell(desc, { width: 2400 }),
                  tableCell(result, { width: 2560 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 100 }),

        heading3("Table 4.3c: RBAC Verification Results"),
        p("Role-based access control (RBAC) was tested by sending authenticated requests with different role tokens to verify that the API correctly enforces authorization boundaries.", { after: 100 }),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [3500, 1200, 1200, 1200, 2260],
          rows: [
            new TableRow({
              children: [
                tableCell("Request", { width: 3500, bold: true, shading: "D5E8F0" }),
                tableCell("Expected", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("Actual", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("Status", { width: 1200, bold: true, shading: "D5E8F0" }),
                tableCell("Explanation", { width: 2260, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["Unauthenticated \u2192 GET /users/me", "401", "401", "PASS", "No JWT token provided"],
              ["Unauthenticated \u2192 GET /accounts", "401", "401", "PASS", "No JWT token provided"],
              ["User role \u2192 POST /accounts", "403", "403", "PASS", "Admin role required for creation"],
              ["User role \u2192 GET /reports/trial-balance", "403", "403", "PASS", "Reporting restricted to FM/Admin/Auditor"],
              ["FinanceManager \u2192 POST /users", "403", "403", "PASS", "Admin role required for user creation"],
              ["FinanceManager \u2192 POST /accounts", "403", "403", "PASS", "Admin role required for account creation"],
              ["Auditor \u2192 POST /journal-entries", "403", "403", "PASS", "Auditor has read-only access"],
              ["Auditor \u2192 GET /audit-logs", "200", "200", "PASS", "Auditor role authorized for audit logs"],
            ].map(([req, expected, actual, status, expl]) =>
              new TableRow({
                children: [
                  tableCell(req, { width: 3500 }),
                  tableCell(expected, { width: 1200 }),
                  tableCell(actual, { width: 1200 }),
                  tableCell(status, { width: 1200 }),
                  tableCell(expl, { width: 2260 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 200 }),

        heading2("4.2 Security Evaluation Plan"),
        p("The security evaluation follows the OWASP risk assessment methodology adapted from Flores and Monreal (2024). Both baseline and post-improvement scans use identical OWASP ZAP configurations with custom rule profiles stored in TSV files (zap-baseline-rules.tsv and zap-api-rules.tsv) that are version-controlled alongside the code. The evaluation focuses exclusively on business API endpoints\u2014findings on Swagger UI or development tooling are excluded from the analysis. All 16 API endpoints listed in Section 3.1 are tested through both passive (baseline) and active (authenticated API) scanning modes.", { indent: true }),

        heading2("4.3 Performance Evaluation Plan"),
        p("Performance evaluation uses Apache JMeter 5.5 running in Docker containers (justb4/jmeter:5.5) to ensure reproducible test environments. The test matrix covers five profiles (50, 100, 500 concurrent users, soak, and spike) targeting all 16 API endpoints. JMeter test plans specify parameterized configurations for base URL, authentication credentials, API version, period ID, and account ID, ensuring consistent test data across runs. Results are compared side by side between the baseline branch and the post-improvement branch, with specific attention to p95 response times, throughput, and error rates for each endpoint and load profile.", { indent: true }),

        heading2("4.4 Code Quality Evaluation Plan"),
        p("Code quality evaluation uses SonarQube Community Edition (v24.12) with the built-in \u201CSonar Way\u201D quality profile, following the methodology established by Yeti\u015Ftiren et al. (2023). The scan is triggered through dotnet-sonarscanner with integration test coverage analysis. Results are compared between the baseline and post-improvement branches, tracking all code smells, bugs, vulnerabilities, and security hotspots. The evaluation specifically examines whether ChatGPT\u2019s recommendations introduced any new issues while resolving existing ones.", { indent: true }),

        heading3("Table 4.4: Test Environment and Data Summary"),
        new Table({
          width: { size: 9360, type: WidthType.DXA },
          columnWidths: [3500, 5860],
          rows: [
            new TableRow({
              children: [
                tableCell("Parameter", { width: 3500, bold: true, shading: "D5E8F0" }),
                tableCell("Value", { width: 5860, bold: true, shading: "D5E8F0" }),
              ],
            }),
            ...([
              ["Operating System", "Windows 11 Home"],
              ["Database", "SQL Server (localhost)"],
              ["Test Accounting Period", "202601 (January 2026)"],
              ["Chart of Accounts", "120 accounts (Assets, Liabilities, Equity, Revenue, Expense)"],
              ["Journal Entries", "30,000 entries (5,000+ posted)"],
              ["User Accounts", "4 roles tested (Admin, FinanceManager, User, Auditor)"],
              ["JMeter Docker Image", "justb4/jmeter:5.5"],
              ["ZAP Docker Image", "ghcr.io/zaproxy/zaproxy:stable"],
              ["SonarQube", "Community Edition v24.12 (Docker)"],
              ["Integration Tests", "105 tests passing (2 unit + 103 integration)"],
              ["Overall Benchmarks", "30 total: 27 PASS, 2 FAIL (drift heuristics on soak/spike)"],
            ].map(([param, value]) =>
              new TableRow({
                children: [
                  tableCell(param, { width: 3500 }),
                  tableCell(value, { width: 5860 }),
                ],
              })
            )),
          ],
        }),
        p("", { after: 200 }),

        heading2("4.5 Comparative Analysis"),
        p("The comparative analysis synthesizes results across all three evaluation dimensions (security, performance, code quality) to provide a holistic assessment of ChatGPT\u2019s effectiveness. Side-by-side comparisons are presented for each metric, with percentage change calculations and statistical significance assessment where applicable. The analysis also examines whether improvements in one dimension created regressions in another\u2014for example, whether performance optimizations introduced new security vulnerabilities, or whether security hardening degraded performance. This integrated analysis approach addresses a gap identified in the literature, where most studies evaluate AI tools on single dimensions rather than across multiple quality aspects simultaneously (Yeti\u015Ftiren et al., 2023; S\u00E1godi et al., 2024).", { indent: true }),
      ],
    },
    // ===== REFERENCES =====
    {
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      children: [
        heading1("References", false),
        ...[
          "Chen, E., Huang, R., Chen, H.-S., Tseng, Y.-H., & Li, L.-Y. (2023). GPTutor: A ChatGPT-powered programming tool for code explanation. In Proceedings of the International Conference on Artificial Intelligence in Education. National Taiwan Normal University.",
          "Efuntade, O. O., & Efuntade, A. O. (2023). Application Programming Interface (API) and Management of Web-Based Accounting Information System (AIS): Security of Transaction Processing System, General Ledger and Financial Reporting System. Journal of Accounting and Financial Management, 9(6), 1\u201318. https://doi.org/10.56201/jafm.v9.no6.2023.pg1.18",
          "Fajkovic, E., & Rundberg, E. (2023). The Impact of AI-generated Code on Web Development: A Comparative Study of ChatGPT and GitHub Copilot [Bachelor\u2019s thesis, Blekinge Institute of Technology]. Faculty of Engineering.",
          "Flores Jr., C. P., & Monreal, R. N. (2024). Evaluation of Common Security Vulnerabilities of State Universities and Colleges Websites Based on OWASP. Journal of Electrical Systems, 20(5s), 1396\u20131404.",
          "Jain, R., Thanvi, J., & Subasinghe, A. (2025). The evolution of ChatGPT for programming: A comparative study. Engineering Research Express, 7, 015242. https://doi.org/10.1088/2631-8695/ada51d",
          "\u00D6zpolat, Z., Y\u0131ld\u0131r\u0131m, \u00D6., & Karabatak, M. (2023). Artificial Intelligence-Based Tools in Software Development Processes: Application of ChatGPT. European Journal of Technique, 13(2).",
          "Peng, S., Kalliamvakou, E., Cihon, P., & Demirer, M. (2023). The Impact of AI on Developer Productivity: Evidence from GitHub Copilot. arXiv:2302.06590v1.",
          "S\u00E1godi, Z., Siket, I., & Ferenc, R. (2024). Methodology for Code Synthesis Evaluation of LLMs Presented by a Case Study of ChatGPT and Copilot. IEEE Access. https://doi.org/10.1109/ACCESS.2024.3403858",
          "Szab\u00F3, Z., & Bilicki, V. (2023). A New Approach to Web Application Security: Utilizing GPT Language Models for Source Code Inspection. Future Internet, 15(10), 326. https://doi.org/10.3390/fi15100326",
          "Yeti\u015Ftiren, B., \u00D6zsoy, I., Ayerdem, M., & T\u00FCz\u00FCn, E. (2023). Evaluating the Code Quality of AI-Assisted Code Generation Tools: An Empirical Study on GitHub Copilot, Amazon CodeWhisperer, and ChatGPT. arXiv:2304.10778v2.",
          "Zhang, N., Zou, Y., Xia, X., Huang, Q., Lo, D., & Li, S. (2023). Web APIs: Features, Issues, and Expectations \u2013 A Large-Scale Empirical Study of Web APIs from Two Publicly Accessible Registries Using Stack Overflow and A User Survey.",
        ].map(ref => p(ref, { after: 120, line: 360, indent: false })),
      ],
    },
  ],
});

// Generate the document
Packer.toBuffer(doc).then(buffer => {
  const outPath = "Document/(Paitoon)Proposal_latest_6519692_ZAWYEHTUTKO_RESULTS_v2.docx";
  fs.writeFileSync(outPath, buffer);
  console.log("Document generated: " + outPath);
}).catch(err => {
  console.error("Error:", err);
});
