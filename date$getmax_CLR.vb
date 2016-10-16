Imports System
Imports System.Data
Imports System.Data.SqlClient
Imports System.Data.SqlTypes
Imports Microsoft.SqlServer.Server

Partial Public Class UserDefinedFunctions
    <SqlFunction(IsDeterministic:=True, DataAccess:=DataAccessKind.None, _
                                              Name:="date$getMax_CLR", _
                                              IsPrecise:=True)> _
    Public Shared Function MaxDate(ByVal inputDate1 As SqlDateTime, _
                                   ByVal inputDate2 As SqlDateTime, _
                                   ByVal inputDate3 As SqlDateTime, _
                                    ByVal inputDate4 As SqlDateTime _
                                           ) As SqlDateTime

        Dim outputDate As SqlDateTime

        If inputDate2 > inputDate1 Then outputDate = inputDate2 _
                                      Else outputDate = inputDate1
        If inputDate3 > outputDate Then outputDate = inputDate3
        If inputDate4 > outputDate Then outputDate = inputDate4

        Return New SqlDateTime(outputDate.Value)

    End Function

End Class