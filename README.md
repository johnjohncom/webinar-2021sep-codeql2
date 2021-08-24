# GitHub Learning Journey: Easy vulnerability hunting with CodeQL

 "Advanced vulnerability hunting with CodeQL session"을 따라하시려면 [링크](README-advanced.md)의 설명을 참조하십시오.

이 워크샵은 CodeQL 쿼리를 작성하는 기본적인 방법을 설명합니다.

- 토픽: jQuery `$` function으로의 불안전한 콜 찾기
- 분석 언어: JavaScript
- 난이도: 1/3

## Setup instructions

1. [Visual Studio Code IDE](https://code.visualstudio.com/download) 설치
1. [CodeQL extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=GitHub.vscode-codeql) 설치. 링크를 클릭하고, 브라우저에서 Visual Studio Code 마켓플레이스가 열리면, install 클릭. 다른 방법으로, VS Code에서 "Extensions" 탭을 열고 CodeQL을 검색.
1.  `git clone --recursive https://github.com/advanced-security/codeql-workshop-2021-learning-journey`을 실행하여, 이 저장소를 클론
   - **중요**: CodeQL 표준 라이브러리는 본 저장소의 서브모듈에 포함되어 있으므로, 리포지토리는 recursively하게 클론해야 함. 만약 초기에 그렇게 하지 못했다면, 저장소 클론 후에 `git submodule update --init --remote`를 실행하여 서브모듈을 가져오면 됩니다. 
1.  workspace 오픈: File > Open Workspace >  `codeql-workshop-2021-learning-journey/codeql-workshop-2021-learning-journey.code-workspace`.
1. 쿼리 작성을 위해, 먼저 보안 취약성 코드 베이스를 가져와야 합니다 :
    - 왼쪽 사이드바에서 **CodeQL** 아이콘을 클릭.
    -  **Databases** section에서, "From a URL (as a zip file)" 버튼 클릭.
    -  https://github.com/advanced-security/codeql-workshop-2021-learning-journey/releases/download/v1.0/esbena_bootstrap-pre-27047_javascript.zip  URL입력.

## 도움 자료 링크들
문제가 생겼다면 아래 도움 자료 문서, 블로그 링크를 통해 도움되는 아이디어를 찾아볼 수 있습니다 :
- [Learning CodeQL](https://help.semmle.com/QL/learn-ql)
- [Learning CodeQL for JavaScript](https://help.semmle.com/QL/learn-ql/javascript/ql-for-javascript.html)
- [Using the CodeQL extension for VS Code](https://help.semmle.com/codeql/codeql-for-vscode.html)

## 쿼리할 보안 문제점 설명

jQuery는 아주 인기있는, 그러나 오래된 오픈소스 JavaScript 라이브러리이며, HTML document traversal이나 조작, 이벤트 핸들링, 애니메이션, Ajax 같은 작업들을 간단하게 처리할 수 있게 해줍니다. jQuery 라이브러리는 기능을 확장하기 위해 모듈화된 플러그인을 지원합니다. Bootstrap은 또 다른 인기있는 JavaScript 라이브러리이며, jQuery의 플러그인 방식을 광범위하게 사용합니다. 그러나, Bootstrap내에 jQuery 플러그인들은 cross-site scripting(XSS) 공격에 취약하게 할 수 있는 안전하지 못한 방식으로 사용되곤 합니다. 이를 이용해 공격자는 보통은 브라우져 사이드 스크립트와 같은 방식으로 악성 코드를 보내는 웹 어플리케이션을 사용하여 다른 사용자에게 악성코드를 보냅니다.  

Bootstrap jQuery plugins의 이러한 보안 취약점은 [이 풀리퀘스트에서](https://github.com/twbs/bootstrap/pull/27047) 보완되었고, 각각 CVE가 할당 되었습니다.

이러한 플러그인들의 핵심적인 문제점은 플러그인으로 전달되는 option들을 처리하기 위해 전능한 기능을 가진 jQuery `$` function의 사용입니다. 예를 들어, 간단한 jQuery plugin인 아래 코드 조각을 보면:

```javascript
let text = $(options.textSrcSelector).text();
```

이 플러그인은 CSS 선택자로 `options.textSrcSelector`를 통해 어느 HTML element가 텍스트를 읽을지를 결정하거나, 또는 최소한 그러한 의도를 가진 코드입니다. 이 예에서 문제점은 `options.textSrcSelector`가 `"<img src=x onerror=alert(1)>"`와 같은 문자열이라면 `$(options.textSrcSelector)`가 JavaScript코드를 실행할 것이라는 점입니다.  

보안 용어에서, jQuery plugin options는 사용자 input의 **source** 이고, `$`의 인자는 XSS **sink**입니다.

위에 링크된 풀리퀘스트는 이러한 플러그인들을 안전하게 만들기 위한 하나의 방법입니다 : `$`대신 더 특정화 되고, 안전한 함수인 `$(document).find` 를 사용하는 것입니다. 
```javascript
let text = $(document).find(options.textSrcSelector).text();
```

이 워크샵에서, 우리는 CodeQL을 이용해 보안 문제점이 해결되기 이전의 Bootstrap 소스코드를 분석하고, 보안 문제점을 찾아낼 것입니다.

## Workshop
이 워크샵은 여러개의 단계로 이루어집니다. 여러분은 한 단계마다 쿼리를 작성하거나, 각 단계에서 수정한 하나의 쿼리를 가지고 작업합니다.

각 단계는 **Hint** 가 제공되고, 여기에서 여러분은 JavaScript를 위한 CodeQL의 표준 라이브러리에서 유용한 클래스들과 predicate(CodeQL에서의 함수)들, CodeQL내 키워드들에 대한 설명들을 보실 수 있습니다. 이러한 설명들은 IDE에서 자동 완성되는 suggestion과 jump-to-definition 명령으로도 찾아 볼 수 있습니다. 

각 단계에서 **Solution** 부분은 가능한 해답을 나타냅니다. 모든 쿼리는 `import javascript`로 시작되어야 하지만, 이것은 아래에서 일일히 표시하지 않았습니다.  

### Finding calls to the jQuery `$` function

1. Find all function call expressions.
    <details>
    <summary>Hint</summary>

    A function call is called a `CallExpr` in the CodeQL JavaScript library.
    </details>
     <details>
    <summary>Solution</summary>
    
    ```
    from CallExpr dollarCall
    select dollarCall
    ```
    </details>

1. Identify the expression that is used as the first argument for each call.
    <details>
    <summary>Hint</summary>

    `Expr`, `CallExpr.getArgument(int)`, `and`, `where`
    </details>
    <details>
    <summary>Solution</summary>
    
    ```
    from CallExpr dollarCall, Expr dollarArg
    where dollarArg = dollarCall.getArgument(0)
    select dollarArg
    ```
    </details>

1. Filter your results to only those calls to a function named `$`.
    <details>
    <summary>Hint</summary>

    `CallExpr.getCalleeName()`
    </details><details>
    <summary>Solution</summary>
    
    ```
    from CallExpr dollarCall, Expr dollarArg
    where
      dollarArg = dollarCall.getArgument(0) and
      dollarCall.getCalleeName() = "$"
    select dollarArg
    ```
    </details>

### Finding accesses to jQuery plugin options
아래 단계를 위해 새로운 쿼리를 작성하거나, 동일한 파일내에서 이전 단계에서 작성된 쿼리들을 주석 처리 하세요. 다음 섹션에서 이전 단계의 쿼리를 다시 사용할 것입니다.

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

1. (Bonus) 단계 2에서의 해답은 보안패치 되지 않은 Bootstrap 코드베이스에서 3개의 alerts를 찾습니다. 이중 2개는 정탐으로서, 위에 링크된 풀리퀘스트에서 해결된 것입니다. 그러나 이러한 순수 syntax한 쿼리의 능력을 넘어서는 추가적인 보안 취약성들이 있습니다. 예를 들어, jQuery option (`something.options.optionName`)으로의 접근은 항상 직접적으로 `$`로의 call의 인자로서만 사용되지 않고, 로컬 변수로 먼저 할당되고, `$`로 전달 될 수도 있습니다.  

    이러한 중간 단계 변수의 사용과 nested expressions들은 검출을 위해서 **data flow analysis**를 사용해야 하는 일반적인 소스코드의 예들 입니다. 

    이 보안 취약점의 하나 또는 그 이상의 변형들을 찾기 위해, 순수 syntax한 구조에 의존하기 보다는, 약간의 JavaScript 데이터 흐름 분석 라이브러리를 시도해 볼 수 있습니다. 아래 Hint에 더 자세한 정보를 참조하세요.

    <details>
    <summary>Hint</summary>

    - `Expr`과 같은 AST노드가 있다면, [`flow()`](https://help.semmle.com/qldoc/javascript/semmle/javascript/AST.qll/predicate.AST$AST$ValueNode$flow.0.html)가 이것을 __data flow node__ 로 바꾸어, 이 expression으로 오고 가는 정보의 흐름에 대한 근거로 사용할 수 있습니다.
    -  data flow node가 있다면, [`getALocalSource()`](https://help.semmle.com/qldoc/javascript/semmle/javascript/dataflow/DataFlow.qll/predicate.DataFlow$DataFlow$Node$getALocalSource.0.html)가 같은 function내에서, 그 값이 이 data flow node에 이르게 되는 다른 data flow node를 찾아 줍니다.  
    - data flow node가 있다면, `asExpr()`은 가능하다면 이것을 AST expression으로 되돌려 줍니다. 
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
