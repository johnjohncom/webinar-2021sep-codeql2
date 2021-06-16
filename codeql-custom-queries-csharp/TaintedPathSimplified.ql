/**
 * @kind path-problem
 */

import csharp
import semmle.code.csharp.frameworks.system.IO
import semmle.code.csharp.dataflow.DataFlow::DataFlow
import semmle.code.csharp.security.dataflow.flowsources.Remote
import semmle.code.csharp.dataflow.DataFlow::DataFlow::PathGraph

/**
 * A path argument to a `File` method call.
 */
class FileCreateSink extends DataFlow::ExprNode {
  FileCreateSink() {
    exists(Method create | create = any(SystemIOFileClass f).getAMethod() |
      this.getExpr() = create.getACall().getArgumentForName("path")
    )
  }
}

class TaintedPathConfiguration extends TaintTracking::Configuration {
  TaintedPathConfiguration() { this = "TaintedPath" }

  override predicate isSource(DataFlow::Node source) {
    source instanceof /** TODO fill me in. */
  }

  override predicate isSink(DataFlow::Node sink) {
    sink instanceof /** TODO fill me in. */
  }

}

from TaintedPathConfiguration c, DataFlow::PathNode source, DataFlow::PathNode sink
where c.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "$@ flows to here and is used in a path.", source.getNode(),
  "User-provided value"
