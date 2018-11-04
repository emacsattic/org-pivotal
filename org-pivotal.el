;;; org-pivotal.el --- Utility to sync Pivotal Tracker to org buffer -*- lexical-binding: t; -*-

;; Copyright (C) 2018 Huy Duong

;; Author: Huy Duong <qhuyduong@hotmail.com>
;; Version: 0.1

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; org-pivotal is a utility to sync Pivotal Tracker to org buffer

;;; Code:

(require 'dash)
(require 'dash-functional)
(require 'ido)
(require 'org)
(require 'subr-x)
(require 'org-pivotal-api)

(defconst org-pivotal--base-url "https://www.pivotaltracker.com"
  "Base URL.")

(defconst org-pivotal--transition-states
  '("Unstarted" "Started" "Finished" "Delivered" "|" "Accepted" "Rejected")
  "Story status will be one of these values.")

(defun org-pivotal--select-project (projects)
  "Prompt user to select a project from PROJECTS."
  (funcall (-compose '(lambda (projects)
                        (let ((ido-max-window-height (1+ (length projects))))
                          (cadr (assoc
                                 (ido-completing-read "Select your project?"
                                                      (-map 'car projects))
                                 projects))))
                     '(lambda (projects)
                        (-map (lambda (project)
                                (list (alist-get 'project_name project)
                                      (alist-get 'project_id project)))
                              projects)))
           projects))

(defun org-pivotal--update-buffer-with-metadata (project my-info)
  "Update org buffer with metadata from PROJECT and MY-INFO."
  (with-current-buffer (current-buffer)
    (erase-buffer)
    (org-mode)
    (org-indent-mode)
    (goto-char (point-min))
    (set-buffer-file-coding-system 'utf-8-auto) ;; force utf-8
    (-map (lambda (item) (insert item "\n"))
          (list ":PROPERTIES:"
                (format "#+PROPERTY: project-name %s" (alist-get 'name project))
                (format "#+PROPERTY: project-id %d" (alist-get 'id project))
                (format "#+PROPERTY: velocity %d" (alist-get 'velocity_averaged_over project))
                (format "#+PROPERTY: url %s/n/projects/%d" org-pivotal--base-url (alist-get 'id project))
                (format "#+PROPERTY: my-id %d" (alist-get 'id my-info))
                (format "#+TODO: %s" (string-join org-pivotal--transition-states " "))
                ":END:"))
    (call-interactively 'save-buffer))
  (org-set-regexps-and-options))

;;;###autoload
(defun org-pivotal-install-project-metadata ()
  "Install selected project's metadata to buffer."
  (interactive)
  (let ((my-info (org-pivotal-api--get-my-info)))
    (let ((project (funcall (-compose 'org-pivotal-api--get-project-info
                                      'org-pivotal--select-project)
                            (alist-get 'projects my-info))))
      (org-pivotal--update-buffer-with-metadata project my-info))))

(defun org-pivotal--convert-story-to-headline (story)
  "Convert STORY to org heading."
  (-map (lambda (item)
          (insert item "\n")
          (org-indent-line))
        (list (format "* %s %s"
                      (upcase-initials (alist-get 'current_state story))
                      (alist-get 'name story))
              ":PROPERTIES:"
              (format ":ID: %s" (alist-get 'id story))
              (format ":Type: %s" (upcase-initials (alist-get 'story_type story)))
              (format ":Points: %s" (alist-get 'estimate story))
              (format ":Updated: %s" (alist-get 'updated_at story))
              (format ":URL: %s" (alist-get 'url story))
              (format ":Description: %s" (alist-get 'description story))
              (format ":Labels: %s" (string-join
                                     (-map (lambda (label) (format "\"%s\""(alist-get 'name label)))
                                           (alist-get 'labels story))
                                     " "))
              ":END:")))

(defun org-pivotal--update-buffer-with-stories (stories)
  "Update org buffer with STORIES."
  (with-current-buffer (current-buffer)
    (org-mode)
    (org-indent-mode)
    (set-buffer-file-coding-system 'utf-8-auto) ;; force utf-8
    (goto-char (point-min))
    (outline-next-heading)
    (kill-region (point-at-bol) (point-max))
    (-map 'org-pivotal--convert-story-to-headline stories)
    (call-interactively 'save-buffer))
  (org-set-regexps-and-options))

;;;###autoload
(defun org-pivotal-pull-stories ()
  "Pull stories to org buffer."
  (interactive)
  (org-set-regexps-and-options)
  (funcall (-compose 'org-pivotal--update-buffer-with-stories
                     'org-pivotal-api--get-stories)
           (string-to-number
            (cdr (assoc-string "project-id" org-file-properties)))
           (cdr (assoc-string "filter" org-file-properties))))

(provide 'org-pivotal)

;;; org-pivotal.el ends here
