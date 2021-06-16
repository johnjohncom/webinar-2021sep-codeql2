
### Want to know more about how you can use CodeQL with commercial code bases? Get in touch with our Sales team using [this contact form](https://enterprise.github.com/contact?utm_source=github&utm_medium=event&utm_campaign=Learning-Journey-part-2-repo).

# GitHub Learning Journey: Advanced vulnerability hunting with CodeQL

This workshop covers how existing queries can be customized to better fit threat models for specific applications.

We recommend completing the [beginner session](README.md) before attempting this session,

- Topic: Find a path traversal vulnerability in a file storage service
- Analyzed language: C#
- Difficulty level: 2/3

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
The out-of-the-box CodeQL query for finding path traversal vulnerabilities follows a standard pattern for queries that look for untrusted data flow. It uses the `TaintTracking` module provided by the CodeQL C# library to help answer the question - "does tainted data flow from this untrusted entry point to this unsafe file API without sanitization". To help use explore these concepts, we can open `TaintedPathSimplified.ql` which provides a simplified version of the query:

1. The query uses a _taint tracking configuration_ to specify "sources" of untrusted data and "sinks" to which the untrusted data should not flow. The simplified query has the template nearly completed. Fill out the `isSource` predicate to specify that the source of untrusted data is remote flow sources.
    <details>
    <summary>Hint</summary>

    The `RemoteFlowSource` class is provided by the standard library to specify all the places that, by default, we believe accept data from remote sources. To use this in the `isSource` predicate we can use the `instanceof` operator to specify that the source is an instanceof `RemoteFlowSource`.
    </details>
    <details>
    <summary>Solution</summary>
    
    ```
    override predicate isSource(DataFlow::Node source) {
      source instanceof RemoteFlowSource
    }
    ```
    </details>

1. Fill out the `isSink` predicate.
    <details>
    <summary>Hint</summary>

    The query includes a `FileCreateSink` class which defines a set of places in the program where files are created. Use this as the sink, by using `instanceof FileCreateSink`.
    </details>
    <details>
    <summary>Solution</summary>
    
    ```
    override predicate isSink(DataFlow::Node sink) {
      sink instanceof FileCreateSink
    }
    ```
    </details>

### Customizing the out-of-the-box query

1. Open the `TaintedPath.ql` query, and use jump-to-definition (F12) to visit `semmle.code.csharp.security.dataflow.TaintedPath::TaintedPath`. How does the default query specify the sources? How can we extend them?
    <details>
    <summary>Hint</summary>
    The default mechanism uses a feature called `abstract` classes. These classes represent _extension points_, and by writing classes that extend them you add to the set of values represented by that class.
    </details>
    <details>
    <summary>Solution</summary>
    The query uses an abstract class `Source` to represent the sources for this query. By default, `Source` is extended once to add all `RemoteFlowSource`s to the set of sources for this query. To add more sources, we simply need to extend
    </details>

1. Implement the `SaveBlobParameterSource` class to add the `SaveBlobStream` and `SaveBlobStreamAsync` parameters as sources for the query.
    <details>
    <summary>Hint</summary>
    Use `exists(Method saveBlobStream | /* add logic here */)` to introduce a local variable to refer to the method.
    </details>
    <details>
    <summary>Solution</summary>
    
    ```
    class SaveBlobParameterSource extends Source {
      SaveBlobParameterSource() {
        exists(Method saveBlobStream |
          saveBlobStream.getName() = "SaveBlobStream" or
          saveBlobStream.getName() = "SaveBlobStreamAsync"
        |
          this.asParameter() = saveBlobStream.getAParameter()
        )
      }
    }
    ```
    </details>

## Next steps

The query we've written identifies the known vulnerabilities in this codebase. These vulnerabilities have since been fixed. However, there may be other similar vulnerabilities in the codebase that have yet to be identified.
