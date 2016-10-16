Imports System
Imports System.Data
Imports System.Data.SqlClient
Imports System.Data.SqlTypes
Imports Microsoft.SqlServer.Server
Imports System.Text

'------------------------------------------------
' Purpose: Aggregates character column as one string separated by commas
' Written: 12/17/2005
' Comment:
'
' User-defined aggregates must be marked as serializable.
'
' SqlUserDefinedAggregate attribute contains data used by SQL Server 2005 
' at runtime and by the Professional version of Visual Studio 
' and above at deployment time.
'
' Format.UserDefined - we must implement IBinarySerialize ourselves
' Name - Name of UDAgg when created in SQL Server (used by VS at deployment)
' MaxByteSize - Maxiumum bytes used for aggregate (used by SQL Server at runtime)
'------------------------------------------------
<Serializable()> _
<SqlUserDefinedAggregate(Format.UserDefined, Name:="String$List", MaxByteSize:=8000)> _
Public Structure List : Implements IBinarySerialize
    Private m_sb As StringBuilder

    ' Called when aggregate is initialized by SQL Server
    Public Sub Init()
        m_sb = New StringBuilder()
    End Sub

    ' returns string representation of List aggregate
    Public Overrides Function ToString() As String
        Return m_sb.ToString()
    End Function

    ' Called once for each row being aggregated - can be null
    Public Sub Accumulate(ByVal value As SqlString)
        ' concatenate strings and separate by a comma
        If Not value.IsNull() Then
            If m_sb.Length > 0 Then
                m_sb.Append(", ")
            End If
            m_sb.Append(value.ToString())
        End If
    End Sub

    ' merge 2 List aggregates togther - used during parallelism
    Public Sub Merge(ByVal value As List)
        Accumulate(New SqlString(value.ToString()))
    End Sub

    ' called when aggregate is finished - return aggregated value
    Public Function Terminate() As SqlString
        Return (New SqlString(m_sb.ToString()))
    End Function

    ' implement IBinarySerialie.Read since we used Format.UserDefined
    Public Sub Read(ByVal r As System.IO.BinaryReader) Implements IBinarySerialize.Read
        m_sb = New StringBuilder(r.ReadString())
    End Sub

    ' implement IBinarySerialie.Write since we used Format.UserDefined
    Public Sub Write(ByVal w As System.IO.BinaryWriter) Implements IBinarySerialize.Write
        w.Write(m_sb.ToString())
    End Sub
End Structure

