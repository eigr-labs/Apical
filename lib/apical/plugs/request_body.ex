defmodule Apical.Plugs.RequestBody do
  @behaviour Plug

  alias Apical.Exceptions.InvalidContentTypeError
  alias Apical.Exceptions.MissingContentTypeError
  alias Plug.Conn

  @impl Plug
  def init([module, version, operation_id, media_type_string, parameters, _plug_opts]) do
    parsed_media_type =
      case Conn.Utils.media_type(media_type_string) do
        {:ok, type, subtype, params} ->
          {type, subtype, params}

        :error ->
          raise CompileError,
            description: "invalid media type in router definition: #{media_type_string}"
      end

    %{}
    |> add_validation(
      module,
      version,
      operation_id,
      media_type_string,
      parsed_media_type,
      parameters
    )
  end

  @impl Plug
  def call(conn, operations) do
    content_type_string = get_content_type_string(conn)

    content_type =
      case Conn.Utils.content_type(content_type_string) do
        {:ok, type, subtype, params} -> {type, subtype, params}
        :error -> raise InvalidContentTypeError, invalid_string: content_type_string
      end

    # TODO: make this respect limits set in configuration
    with {:ok, body, conn} <- Conn.read_body(conn),
         # NB: this code will change
         body_params = Jason.decode!(body) do
      conn
      |> validate!(body_params, content_type_string, content_type, operations)
      |> Map.replace!(:body_params, body_params)
      |> Map.update!(:params, &update_params(&1, body_params, false))
    else
      {:error, _} -> raise "fatal error"
    end
  end

  @spec get_content_type_string(Conn.t()) :: String.t()
  defp get_content_type_string(conn) do
    if content_type_header = List.keyfind(conn.req_headers, "content-type", 0, nil) do
      elem(content_type_header, 1)
    else
      raise MissingContentTypeError
    end
  end

  defp update_params(params, body_params, nested) when is_map(body_params) and not nested do
    # we merge params into body_params so that malicious payloads can't overwrite the cleared
    # type checking performed by the params parsing.
    Map.merge(body_params, params)
  end

  defp update_params(params, body_params, _) do
    # non-object JSON content is put into a "_json" field, this matches the functionality found
    # in Plug.Parsers.JSON
    #
    # objects can also be forced into "_json" by setting :nest_all_json
    #
    # see: https://hexdocs.pm/plug/Plug.Parsers.JSON.html#module-options
    Map.put(params, "_json", body_params)
  end

  defp add_validation(operations, module, version, operation_id, media_type_string, media_type, %{
         "schema" => _schema
       }) do
    fun = {module, validator_name(version, operation_id, media_type_string)}

    Map.update(operations, :validations, %{media_type => fun}, &Map.put(&1, media_type, fun))
  end

  defp validate!(conn, body_params, content_type_string, content_type, %{validations: validations}) do
    {module, fun} = fetch_validation!(validations, content_type_string, content_type)

    case apply(module, fun, [body_params]) do
      :ok ->
        conn

      {:error, reasons} ->
        raise Apical.Exceptions.ParameterError,
              [operation_id: conn.private.operation_id, in: :body] ++ reasons
    end
  end

  defp validate!(conn, _, _, _, _), do: conn

  def validator_name(version, operation_id, mimetype) do
    :"#{version}-body-#{operation_id}-#{mimetype}"
  end

  defp fetch_validation!(
         validations,
         content_type_string,
         content_type = {_req_type, _req_subtype, _req_param}
       ) do
    if validation =
         Enum.find_value(validations, fn
           {^content_type, fun} -> fun
           _ -> nil
         end) do
      validation
    else
      raise Plug.Parsers.UnsupportedMediaTypeError, media_type: content_type_string
    end
  end
end
