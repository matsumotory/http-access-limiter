test_suite do
  "FailedRequests".should_be                   0
  #"WriteErrors".should_be                      0
  "CompleteRequests".should_be                 100000
  #"TransferRate".should_be_over                500
  "RequestPerSecond".should_be_over            1
  #"TimePerRequest".should_be_under             100
  #"TimePerConcurrentRequest".should_be_under   3000
  #"ConnetcErrors".should_be                    0
  #"ReceiveErrors".should_be                    0
  #"LengthErrors".should_be                     0
  #"ExceptionsErrors".should_be                 0
  "Non2xxResponses".should_be                  0
end

test_run
