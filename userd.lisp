(defvar *tasks* nil)

(defun add-task (cmd args logfile)
  (push (list :cmd cmd :args args :logfile logfile :subproc nil) *tasks*))

(defun run-task (task)
  (setf (getf task :subproc)
        (nth-value 2
                   (ext:run-program (getf task :cmd) (getf task :args)
                                    :input nil
                                    :if-input-does-not-exist :create
                                    :output (open (getf task :logfile)
                                                  :direction :output
                                                  :if-exists :append
                                                  :if-does-not-exist :create
                                                  )
                                    :if-output-exists :append
                                    :wait nil))))

(defun run-tasks ()
  (dolist (task *tasks*)
    (run-task task)
    ))

(defun poll-tasks ()
  (format t "start poll tasks...~%")
  (dolist (task *tasks*)
    (let ((taskstatus (ext:external-process-status (getf task :subproc))))
      (if (member taskstatus '(:abort :error :exited :stopped))
          (progn
            (format t "~a stopped, restarting...~%" (getf task :cmd))
            (run-task task)
            )
          )
      ))
  (format t "all tasks are polled~%")
  )

(defun handle-dead-subproc ()
  (format t "receive +SIGCHLD+~%")
  (poll-tasks)
  )

(add-task "wireplumber" nil "~/.local/log/wireplumber.log")
(add-task "pipewire-pulse" nil "~/.local/log/pipewire-pulse.log")
(add-task "pipewire" nil "~/.local/log/pipewire.log")
(add-task "onedrive" '("--monitor") "~/.local/log/onedrive.log")

(run-tasks)

(ext:catch-signal ext:+sigchld+ :catch)
(ext:set-signal-handler ext:+sigchld+ #'handle-dead-subproc)

(loop (sleep 1))
