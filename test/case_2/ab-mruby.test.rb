test_suite do
  "FailedRequests".should_be                   1
  #"WriteErrors".should_be                      0
  "CompleteRequests".should_be                 10
  #"TransferRate".should_be_over                500
  #"RequestPerSecond".should_be_over            1000
  #"TimePerRequest".should_be_under             100
  #"TimePerConcurrentRequest".should_be_under   3000
  #"ConnetcErrors".should_be                    0
  #"ReceiveErrors".should_be                    0
  #"LengthErrors".should_be                     0
  #"ExceptionsErrors".should_be                 0
  "Non2xxResponses".should_be                  9
end

test_run
