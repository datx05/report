defmodule ThesisWeb.SubmissionLiveView do
  use Phoenix.LiveView

  def render(assigns) do
    ThesisWeb.SubmissionView.render("log.html", assigns)
  end

  def mount(
        %{submission: submission, job: job, events: events} = _session,
        socket
      ) do
    if connected?(socket) do
      EventStore.subscribe_to_stream(job.id, UUID.uuid4(), self(), start_from: length(events))
    end

    {:ok,
     assign(socket,
       submission: submission,
       log_lines: map_events(events)
     )}
  end

  def mount(%{submission: submission} = _session, socket) do
    {:ok,
     assign(socket,
       submission: submission,
       log_lines: [{:error, "No job specified"}]
     )}
  end

  def handle_info({:subscribed, subscription}, socket) do
    {:noreply, assign(socket, :subscription, subscription)}
  end

  def handle_info({:events, events}, socket) do
    EventStore.ack(socket.assigns.subscription, events)

    {:noreply, update(socket, :log_lines, &(&1 ++ map_events(events)))}
  end

  defp map_events(events) do
    Enum.map(events, fn %EventStore.RecordedEvent{data: data} ->
      case data do
        :init ->
          {:init, "Coderunner started job"}

        {:pull, :end} ->
          {:done, "Image fetching done. Will now execute the job..."}

        {:run, :end} ->
          {:done, "Process execution successful"}

        {:pull, {_stream, text}} ->
          {:text, text}

        {:run, {:stdio, text}} ->
          {:text, text |> String.replace(~r/\n$/, "")}

        {:run, {:stderr, text}} ->
          {:supervisor, text |> String.replace(~r/\n$/, "")}

        {:error, text} ->
          {:error, inspect(text)}
      end
    end)
  end
end
