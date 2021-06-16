# GitHub Learning Journey: Advanced vulnerability hunting with CodeQL

This workshop covers how existing queries can be customized to better fit threat models for specific applications.

We recommend completing the [beginner session](README.md) before attempting 

- Topic: Find a path traversal vulnerability in a StorageService
- Analyzed language: C#
- Difficulty level: 1/3

## Setup instructions
1. If you have not already done so, follow Steps 1.-3. from the [Setup instructions](README.md#setup-instructions) from the previous workshop to install VS Code and the CodeQL extension.
1. Run `git pull` to ensure you have fetched the files for this session.
1. Open the workspace: File > Open Workspace > Browse to `codeql-workshop-2021-learning-journey/codeql-workshop-2021-learning-journey.code-workspace`.
1. In order to write queries, we will first need to import a database representing the vulnerable codebase. To do so:
    - Click the **CodeQL** icon in the left sidebar.
    - Under the **Databases** section, click the button labeled "From a URL (as a zip file)".
    - Enter https://github.com/advanced-security/codeql-workshop-2021-learning-journey/releases/download/v1.0/TwentyTwenty.Storage-2.11.0.zip as the URL.

## Documentation links
If you get stuck, try searching our documentation and blog posts for help and ideas. Below are a few links to help you get started:
- [Learning CodeQL](https://help.semmle.com/QL/learn-ql)
- [Learning CodeQL for C#](https://help.semmle.com/QL/learn-ql/csharp/ql-for-csharp.html)
- [Using the CodeQL extension for VS Code](https://help.semmle.com/codeql/codeql-for-vscode.html)

## Problem statement

A _path traversal_ vulnerability is typically caused by using untrusted data in one or more file API calls. This is problematic because certain character sequences will be _interpreted_ by the underlying operating system file APIs, which can lead to reading or writing files from unexpected locations on the file system. The most common example is the `..` sequence, which represents "traverse to the parent directory". If an attacker can provide a sequence like:
```
../../../etc/passwd
```
They can potentially access, write to or delete the given file.

In this workshop we will look at a path traversal vulnerability found in a C# library called [`TwentyTwenty.Storage`](https://github.com/2020IP/TwentyTwenty.Storage), a library which provides a consistent API for writing files to various local and cloud-based storage providers, such as Azure Blob Storage and AWS. The [vulnerability](http://security401.com/twentytwenty-storage-path-traversal/) was identified by a security researcher, and [fixed](https://github.com/2020IP/TwentyTwenty.Storage/commit/85f97b7747552a2d65702046ca18c6e048d8b102) in May 2019.

The CodeQL default query set ships with a [query](https://github.com/github/codeql/blob/main/csharp/ql/src/Security%20Features/CWE-022/TaintedPath.ql) for finding tainted path vulnerabilities. However, if we run this query on the vulnerable version of the codebase, we find it reports no results. This is because the tainted data arrives via a _library call_, which is not part of the default threat model CodeQL uses. Reporting unsafe operations via potential library entry poitns produces a large number of false positives for most codebases. However, clearly in this case

## Workshop
The workshop is split into several steps. You can write one query per step, or work with a single query that you refine at each step.

Each step has a **Hint** that describe useful classes and predicates in the CodeQL standard libraries for C# and keywords in CodeQL. You can explore these in your IDE using the autocomplete suggestions and jump-to-definition command.

Each step has a **Solution** that indicates one possible answer. Note that all queries will need to begin with `import csharp`, but for simplicity this may be omitted below.

### Finding parameters of the `SaveBlobStream` method

In this first exercise, we will write a short query to find parameters of the library methods which were vulnerable to path traversal attacks. Start by opening the `SaveBlobStream.ql` query.

1. Find methods called `SaveBlobStream` and `SaveBlobStreamAsync`
    <details>
    <summary>Hint</summary>

    A method is called a `Method` in the CodeQL C# library. The simplest way to identify both methods is to use `.getName()` and an `or` to combine conditions, but you may want to use a regular expression with `.regexpMatch` to shorten your query.
    </details>
     <details>
    <summary>Solution</summary>
    
    ```
    from Method saveBlobStream
    where
      saveBlobStream.getName() = "SaveBlobStream" or
      saveBlobStream.getName() = "SaveBlobStreamAsync"
    select saveBlobStream
    ```
    </details>

1. Identify parameters of those methods.
    <details>
    <summary>Hint</summary>

    `Method.getAParameter()`
    </details>
    <details>
    <summary>Solution</summary>
    
    ```
    from Method saveBlobStream
    where
      saveBlobStream.getName() = "SaveBlobStream" or
      saveBlobStream.getName() = "SaveBlobStreamAsync"
    select saveBlobStream, saveBlobStream.getAParameter()
    ```
    </details>

### Understanding the out-of-the-box tainted path query
The out-of-the-box CodeQL query for finding path traversal vulnerabilities follows a standard pattern fo

1. Opemn

1. When a jQuery plugin option is accessed, the code generally looks like `something.options.optionName`. First, identify all accesses to a property named `options`.
    <details>
    <summary>Hint</summary>

    Property accesses are called `PropAccess` in the CodeQL JavaScript libraries. Use `PropAccess.getPropertyName()` to identify the property.
    </details>
    <details>
    <summary>Solution</summary>
    
    ```
    from PropAccess optionsAccess
    where optionsAccess.getPropertyName() = "options"
    select optionsAccess
    ```
    </details>

1. Take your query from the previous step, and modify it to find chained property accesses of the form `something.options.optionName`.
    <details>
    <summary>Hint</summary>

    There are two property accesses here, with the second being made upon the result of the first. `PropAccess.getBase()` gives the object whose property is being accessed.
    </details>
    <details>
    <summary>Solution</summary>
    
    ```
    from PropAccess optionsAccess, PropAccess nestedOptionAccess
    where
      optionsAccess.getPropertyName() = "options" and
      nestedOptionAccess.getBase() = optionsAccess
    select nestedOptionAccess
    ```
    </details>

### Putting it all together

1. Combine your queries from the two previous sections. Find chained property accesses of the form `something.options.optionName` that are used as the argument of calls to the jQuery `$` function.
    <details>
    <summary>Hint</summary>
    Declare all the variables you need in the `from` section, and use the `and` keyword to combine all your logical conditions.
    </details>
    <details>
    <summary>Solution</summary>
    
    ```
    from CallExpr dollarCall, Expr dollarArg, PropAccess optionsAccess, PropAccess nestedOptionAccess
    where
      dollarCall.getArgument(0) = dollarArg and
      dollarCall.getCalleeName() = "$" and
      optionsAccess.getPropertyName() = "options" and
      nestedOptionAccess.getBase() = optionsAccess and
      dollarArg = nestedOptionAccess
    select dollarArg
    ```
    </details>

1. (Bonus) The solution to step 2 should result in a query with three alerts on the unpatched Bootstrap codebase, two of which are true positives that were fixed in the linked pull request. There are however additional vulnerabilities that are beyond the capabilities of a purely syntactic query such as the one we have written. For example, the access to the jQuery option (`something.options.optionName`) is not always used directly as the argument of the call to `$`: it might be assigned first to a local variable, which is then passed to `$`.

    The use of intermediate variables and nested expressions are typical source code examples that require use of **data flow analysis** to detect.

    To find one more variant of this vulnerability, try adjusting the query to use the JavaScript data flow library a tiny bit, instead of relying purely on the syntactic structure of the vulnerability. See the hint for more details.

    <details>
    <summary>Hint</summary>

    - If we have an AST node, such as an `Expr`, then [`flow()`](https://help.semmle.com/qldoc/javascript/semmle/javascript/AST.qll/predicate.AST$AST$ValueNode$flow.0.html) will convert it into a __data flow node__, which we can use to reason about the flow of information to/from this expression.
    - If we have a data flow node, then [`getALocalSource()`](https://help.semmle.com/qldoc/javascript/semmle/javascript/dataflow/DataFlow.qll/predicate.DataFlow$DataFlow$Node$getALocalSource.0.html) will give us another data flow node in the same function whose value ends up in this node.
    - If we have a data flow node, then `asExpr()` will turn it back into an AST expression, if possible.
    </details>
    <details>
    <summary>Solution</summary>
    
    ```
    from CallExpr dollarCall, Expr dollarArg, PropAccess optionsAccess, PropAccess nestedOptionAccess
    where
      dollarCall.getArgument(0) = dollarArg and
      dollarCall.getCalleeName() = "$" and
      optionsAccess.getPropertyName() = "options" and
      nestedOptionAccess.getBase() = optionsAccess and
      dollarArg.flow().getALocalSource().asExpr() = nestedOptionAccess
    select dollarArg, nestedOptionAccess
    ```
    </details>

## Acknowledgements

This is a reduced version of a Capture-the-Flag challenge devised by @esbena, available at https://securitylab.github.com/ctf/jquery. Try out the full version!
