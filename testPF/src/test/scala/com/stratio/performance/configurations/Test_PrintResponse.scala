
/*
 * © 2017. Stratio Big Data Inc., Sucursal en España. All rights reserved.
 *
 * This software – including all its source code – contains proprietary information of Stratio Big Data Inc.,
 * Sucursal en España and may not be revealed, sold, transferred, modified, distributed or otherwise made
 * available, licensed or sublicensed to third parties; nor reverse engineered, disassembled or decompiled
 * without express written authorization from Stratio Big Data Inc., Sucursal en España.
 */

package com.stratio.performance.configurations

import com.stratio.performance.common.CommonPrintResponse
import io.gatling.core.session.Session

trait Test_PrintResponse extends CommonPrintResponse {

  def printResult(session : Session) = {
    verbosity match {
      case "FULL" => {
        println("Some Restful Service Response Body:")
        println(session("RESPONSE_DATA").as[String])
      }
      case "LENGTH" => {
        println("Some Restful Service Response Body Length:")
        println(session("RESPONSE_DATA").as[String].length)
      }
      case _ => {
      }
    }
  }

  override val verbosity: String = System.getProperty("VERBOSITY", "")

}
